---
name: pi-serial-console
description: Log in to, reboot, inspect, debug or health-check a real Raspberry Pi (pi0, the Pi Zero) running this LFS system over a USB-TTL serial console from the Mac. Covers driving the port reliably, reading boot output, the baseline of a healthy boot, and the traps. Not for QEMU (use ./test and `./lfs qemu`).
---

# Raspberry Pi serial console

The pi0 image has no display console, no network and no USB: the only way in is the UART
(`console=ttyAMA0,115200`, a PL011). A USB-TTL adapter connects GND (pin 6), TX and RX (pins 8 and 10,
GPIO 14 and 15) to the Mac, where it appears as `/dev/cu.usbserial-*`. Settings are 115200 8N1, no
flow control. The adapter seen so far is a Prolific PL2303; the port number changes with the USB port.

## Use the bundled driver

`pi_console.py` (next to this file) is standard-library Python. Run it from anywhere:

```bash
S=.claude/skills/pi-serial-console/pi_console.py
python3 $S ports                              # candidate ports, and who holds them
python3 $S run 'uname -a' 'systemctl is-system-running'   # log in, run one-line commands
python3 $S reboot --log boot.log              # log in, reboot, capture the boot, summarise
python3 $S watch 60                           # record the console without sending anything
```

It logs in as root, prints each command's output and exit status, and recovers by itself from the
failures below. The root password comes from the boot test (`./test`), or `PI_ROOT_PASSWORD`; do not
copy it into notes or replies.

## Rules that save time

1. **One program on the port.** The user's own `tio`/`screen` usually holds it, and a second reader
   splits the bytes. `ports` shows holders. Ask the user to quit theirs (tio: Ctrl-T then q); never
   kill it. The driver refuses to start while the port is held.
2. **Do not use `expect` + `tio` (or a raw Tcl channel).** Reads failed with EOF at the same points of
   every reboot (during shutdown and again during boot), each costing 0.5 to 1.5 s of output, and tio
   exited silently with status 1. The USB device never disappeared. The direct `termios` driver, which
   reopens the tty on any error, saw zero errors across two reboots and a dozen long sessions. Do not
   spend time on the cause.
3. **Pace the input (3 ms per byte).** The UART FIFO is 16 bytes and the CPU is busy during SD card
   I/O (PIO), so a command sent at line rate loses characters: the kernel logs
   `ttyAMA0: 1 input overrun(s)`, and `/proc/tty/driver/ttyAMA` shows `oe:N`. A garbled line can leave
   the shell inside an open quote (prompt `>`) so that every later command is swallowed and every
   wait times out. Send Ctrl-C three times to recover; `login()` does this.
4. **Never `poweroff` or `halt`.** There is no remote power-on; the user would have to replug the
   board. `reboot` is safe: systemd arms the hardware watchdog when it shuts down.
5. **Synchronise on a marker the shell computes**, e.g. `echo "<<END$((100000+n))>>$?"`. The terminal
   echoes the command line back, so a literal marker in the command matches its own echo.
6. **Errors from systemd tools go to the journal, not the console.** A command that exits 1 with no
   output: run `journalctl -n 20 --no-pager`.
7. The shell is bash invoked as `sh` (prompt `-sh-5.3# `). Commands are single lines (no heredocs)
   typed into the interactive shell; `stty cols 1000` is set at login so that readline does not redraw
   long lines.

## Reading the output

The console carries escape sequences that a terminal emulator would answer: colours, cursor-position
queries (`ESC[6n`), a terminal-name query that prints as `P+q6E616D65\`, and OSC context markers.
Strip them (`clean()` does) and never mirror raw console output to a live terminal, which would reply
into the Pi's input. Kernel lines carry no timestamps on the console; `dmesg` has them.

In the captured reboots nothing from the GPU firmware (`bootcode.bin`, `start.elf`) reaches the UART
between `reboot: Restarting system` and the first kernel line, `Booting Linux on physical CPU 0x0`,
about 2.4 s later. The kernel, `systemd 260.2` and the `[  OK  ]` unit lines follow, ending at
`localhost login:`.

## Baseline of a healthy boot (Pi Zero Rev 1.3, kernel 6.18.34-pi0, 32 GB card)

From the `reboot` command: shutdown finished +4.1 to 4.6 s, kernel starts +6.5 to 7.0 s, `init` +8.0
to 8.5 s, serial getty +20 s, login prompt +22 to 23 s. `systemd-analyze`: 2.2 s kernel plus 11.2 to
11.8 s userspace. The slowest units wait for the SD card: `dev-mmcblk0p2.device` 7.3 s,
`systemd-remount-fs` 4.9 s.

After login: `systemctl is-system-running` prints `running`; `systemctl --failed` is empty;
`/proc/sys/kernel/tainted` is `0`; no `oe:` in `/proc/tty/driver/ttyAMA`. About 435 MB RAM with 23 MB
used, 46 tasks, and only `init`, `systemd-journald`, `systemd-udevd` and `serial-getty` as services.
The card runs at 50 MHz, 4-bit, SD high-speed (`/sys/kernel/debug/mmc0/ios`); an 8 MiB fsynced write
measures 4.7 MB/s and a cold read 9.5 MB/s. The btrfs error counters
(`/sys/fs/btrfs/*/devinfo/1/error_stats/*`) are all 0.

### Messages that are expected

- `OF: reserved mem: node linux,cma compatible matching fail`: the vendor device tree has a CMA node
  the kernel lacks.
- `sdhost-bcm2835 ...: unable to initialise DMA channel. Falling back to PIO` and `loaded - DMA
  disabled`: deliberate. `package/linux/pi0.config` leaves `CONFIG_DMADEVICES` off (the 6.18
  `bcm2835-dma` regression raspberrypi/linux#7136, and QEMU's broken DMA). It costs SD throughput.
- `check access for rdinit=/init failed: -2, ignoring`: there is no initramfs.
- `mmc0: host does not support reading read-only switch, assuming write-enable`.
- `tmp.mount: x-systemd.graceful-option=usrquota ... suppressing`; `Kernel Trace File System` and
  `configfs` module skipped.
- Five `systemd-sysctl: Couldn't write ... kernel/sysrq, kernel/core_uses_pid, net/ipv4/conf/default/*`
  warnings: the kernel has neither SysRq nor an IPv4 stack.
- `watchdog: watchdog0: watchdog left running` at shutdown: `systemd-shutdown` arms a 10 minute
  hardware watchdog on purpose.
- `systemctl list-units --all` marks not-found units with a dot (`auditd`, `display-manager`,
  `plymouth-*`, `syslog`, ...): dangling references, not failures. Use `systemctl --failed`.

### Absent by design (do not report as faults)

No networking (only `lo`), USB, LED class, thermal or hwmon (so undervoltage cannot be detected), RTC,
input, graphics, cpufreq or swap. No D-Bus: `systemd-run --wait`/`--pipe` and `busctl` fail with
`Failed to connect to system scope bus` (in the journal); plain `systemd-run` and `--scope` work.
`/etc/hostname` is absent (the name is `localhost`). The clock has no source: every boot starts at
systemd's built-in epoch (2026-05-27 08:37 UTC), so times from the Pi are not real. The machine ID
persists across reboots. `find`, `tar`, `less`, `file` and `ip` are not installed.

## A health-check pass

```bash
python3 $S run \
  'systemctl is-system-running; systemctl --no-pager --failed; systemd-analyze' \
  'systemd-analyze blame --no-pager | head; systemd-analyze critical-chain --no-pager' \
  'dmesg --level=emerg,alert,crit,err,warn; cat /proc/sys/kernel/tainted' \
  'journalctl -b --no-pager -p warning | cut -c1-200' \
  'cat /proc/interrupts /proc/partitions; free -m; df -h; mount' \
  'cat /proc/tty/driver/ttyAMA | tail -1' \
  'cd /root && dd if=/dev/urandom of=t.bin bs=1M count=8 conv=fsync 2>&1 | tail -1; sha256sum t.bin > t.sum; sync; echo 3 > /proc/sys/vm/drop_caches; sha256sum -c t.sum; rm -f t.bin t.sum'
```

Compare against the baseline above. Then `reboot --log` and check that the machine ID is unchanged and
the boot ID differs.
