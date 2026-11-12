# What a real Pi Zero boot looks like (Pi Zero Rev 1.3, kernel 6.18.34-pi0, 32 GB card, serial console)

Measured on hardware on 2026-10-12, then updated for the later image changes. Use it to judge a QEMU run and
the user's first real boot. The serial-console driver script and its rules (`pi_console.py`, a direct-termios
driver with paced input: expect+tio dropped the stream) are in git history: `git show
6fbfb75^:.claude/skills/pi-serial-console/`. Never `poweroff` a real Pi (no remote power-on): `reboot` is safe.

## A healthy boot

From `reboot`: shutdown done +4.1-4.6 s, kernel starts +6.5-7.0 s, `init` +8.0-8.5 s, serial getty +20 s, login
prompt +22-23 s. `systemd-analyze`: 2.2 s kernel + 11.2-11.8 s userspace; the slowest units wait for the SD card
(`dev-mmcblk0p2.device` 7.3 s, `systemd-remount-fs` 4.9 s). After login: `is-system-running` = `running`,
`--failed` empty, `/proc/sys/kernel/tainted` 0, no `oe:` in `/proc/tty/driver/ttyAMA`, ~435 MB RAM with 23 MB
used, 46 tasks, services only `init`, `systemd-journald`, `systemd-udevd`, `serial-getty`. The card runs at 50 MHz,
4-bit, SD high speed (`/sys/kernel/debug/mmc0/ios`); an 8 MiB fsynced write is 4.7 MB/s, a cold read 9.5 MB/s;
btrfs error counters (`/sys/fs/btrfs/*/devinfo/1/error_stats/*`) are 0.

## Messages that are expected

- `OF: reserved mem: node linux,cma compatible matching fail`: the vendor devicetree has a CMA node the kernel lacks.
- `sdhost-bcm2835 ...: unable to initialise DMA channel. Falling back to PIO` and `loaded - DMA disabled`: deliberate
  (`CONFIG_DMADEVICES` off: the 6.18 bcm2835-dma regression raspberrypi/linux#7136, and QEMU's broken DMA); costs SD speed.
- `check access for rdinit=/init failed: -2, ignoring`: no initramfs.
- `tmp.mount: x-systemd.graceful-option=usrquota ... suppressing`; `Kernel Trace File System`, `Huge Pages File System`
  and `configfs` skipped: the kernel lacks them.
- With USB: `dwc2 ...: dwc2_check_params: Invalid parameter max_packet_count=511` and `max_transfer_size=65535` (seen
  under QEMU, unconfirmed on silicon), `sd 0:0:0:0: Power-on or device reset occurred` when a stick is plugged in,
  and at info level `PM: genpd: Disabling unused power domains` and `raspberrypi-power ...: sync_state() pending due
  to ...v3d/hdmi/vec` (nothing uses those domains).
- `watchdog: watchdog0: watchdog left running` at shutdown: systemd-shutdown arms a 10 minute hardware watchdog on purpose.
- `systemctl list-units --all` marks not-found units with a dot (`auditd`, `display-manager`, `plymouth-*`, ...):
  dangling references, not failures; use `systemctl --failed`.
- QEMU only: `initcall_blacklist requires CONFIG_KALLSYMS`.

## Absent by design (not faults)

No networking (only `lo`), LED class, thermal or hwmon (undervoltage cannot be detected), RTC, input, graphics, cpufreq
or swap. USB only with the `usb` capability (a profile names it in its `capabilities`). No D-Bus: `systemd-run --wait`/`--pipe` and `busctl`
fail with `Failed to connect to system scope bus` (journal); plain `systemd-run` and `--scope` work. No
`/etc/hostname` (the name is `localhost`). The clock has no source: timesyncd saves it every minute and at shutdown and
the next boot continues from it; a new image starts at its build time; real times need `date -u -s`. The machine ID is
made with the image and persists. `find`, `tar`, `less`, `file`, `ip` are not installed.

## A health-check pass (one line each in the guest; `qemu-check` runs them under QEMU too)

```sh
systemctl is-system-running; systemctl --no-pager --failed; systemd-analyze
systemd-analyze blame --no-pager | head; systemd-analyze critical-chain --no-pager
dmesg --level=emerg,alert,crit,err,warn; cat /proc/sys/kernel/tainted
journalctl -b --no-pager -p warning | cut -c1-200
cat /proc/interrupts /proc/partitions; free -m; df -h; mount; cat /proc/tty/driver/ttyAMA | tail -1
cd /root && dd if=/dev/urandom of=t.bin bs=1M count=8 conv=fsync 2>&1 | tail -1; sha256sum t.bin > t.sum; sync; echo 3 > /proc/sys/vm/drop_caches; sha256sum -c t.sum; rm -f t.bin t.sum
```
On hardware, then `reboot --log` and check that the machine ID is unchanged and the boot ID differs.
