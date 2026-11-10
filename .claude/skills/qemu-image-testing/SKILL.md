---
name: qemu-image-testing
description: Boot-test a built image (pi0, virt, arm64, amd64) under QEMU - run guest commands, diff the boot's warnings against a baseline, emulate USB sticks and readers, pass a real YubiKey through, answer PIN prompts, test the clock across boots. Use after any change that ends up in an image, and before burning a card or trusting a build. Not for the real Pi or for building (lfs-build-iteration).
model: sonnet
---

# Testing images under QEMU

`qemu-check` spawns `./lfs qemu` (as `./test` does), so each platform runs the command its
`platform/<platform>.sh` defines. Needs the built image (`make docker-image/<key>.img`), `expect` and the
platform's `qemu-system-*`. Paths are from the repo root; `Q=.claude/skills/qemu-image-testing/scripts`.

## Run

```sh
$Q/qemu-check [--print] KEY ["EXTRA QEMU ARGS" ["GUEST COMMAND"]]
$Q/qemu-check pi0-systemd+fido2+gnupg+yubikey-manager "-device usb-ccid" 'ykman list --readers'
```
Boots a COPY of `image/KEY.img`, logs in as root (password `root`), runs ONE guest line, powers off, prints
only that line's output (on failure: the end of the console and its path). `./lfs qemu` boots an image through
a qcow2 overlay next to it (`x.img` through `x.qcow2`), which keeps what the system writes until the image is
made anew: the image itself is never written, and the copy gives each check a fresh overlay. Env:
`IMAGE_COPY=path` keeps a copy (and its overlay) across calls, `EXPECT_SCRIPT=` runs your own script (see
Prompts), `VERBOSE=1`, `TIMEOUT=s` (400), `STATE_DIR=`. `--print` prints the quoted QEMU command for
`image/KEY.qemu.img` (made, with `image/KEY.qemu.qcow2`; delete both after): to see what a platform runs, or
to hand the user a command that needs root.

## Checks and baselines

```sh
$Q/qemu-check KEY "" "$(cat $Q/check-boot.cmd)"   # state, failed units, dmesg and journal warnings
$Q/check-baseline [--save] KEY ["EXTRA ARGS"]      # the same, diffed against baselines/KEY.txt
```
"No warnings" means those two lists, not the console. A baseline is per key and per extra args; recorded: the
pi0 ykman key (with `-device usb-ccid`) and both virt keys, with `+man+procps+tzdata`, which hold the whole of
chapter 8. Without one the run is printed: judge it once by hand (real-Pi baseline:
`reference/pi0-real-boot.md`), then `--save`. A new diff line is new: look. Without util-linux's tools (`dmesg`),
the check reads the kernel's warnings from the journal.

Known noise. pi0 under QEMU: `initcall_blacklist requires CONFIG_KALLSYMS` (QEMU-only), two `dwc2_check_params:
Invalid parameter max_packet_count/max_transfer_size` (QEMU's registers; unconfirmed on silicon), `sdhost ...
Falling back to PIO` and `check access for rdinit=/init failed` (real). virt: `pci-host-generic ...
Memory resource size exceeds max for 32 bits`. An attached stick adds `sd 0:0:0:0: Power-on or device reset occurred`.

## Platforms

| | pi0 | virt | arm64, amd64 |
|---|---|---|---|
| Machine | `raspi0`, TCG, ~30 s per check | the Mac's arch with HVF (KVM on Linux), ~10 s | `virt`/`q35`, `-cpu max`, accelerator fallbacks |
| Console, disk | `ttyAMA0`, `mmcblk0p2`, DTB | virtio `hvc0` on stdio shared with the monitor (Ctrl-A c), `vda1`, no DTB | `ttyAMA0`/`ttyS0`, `vda1` |
| USB | DWC2 behind a hub | `qemu-xhci` | `qemu-xhci` |
| Tested | end to end | end to end; a real key through HVF as root untested | dry run only |

New platform: `--print`, a plain `qemu-check KEY`, then `check-baseline --save`. Reader names carry the
guest's bus path (`(1-0000:00:02.0-1)` virt, `(1-1.1)` pi0): do not match them literally. The Zero has one USB
data port, so real use needs a hub. The emulated reader is 08E6:4433 (in ccid's Info.plist).

## Also

- Missing libraries and RPATHs first: `missing-libs` (lfs-build-iteration).
- Clock across boots: `IMAGE_COPY=/tmp/x.img`; `qemu-check KEY "" 'date -u -s "2026-12-31 12:00:00"; sleep 75'`
  (timesyncd saves every 60 s and at exit), then `... 'date -u'`: it continues from the saved time and PID 1
  logs "System time advanced to timestamp on /var/lib/systemd/timesync/clock". Delete `/tmp/x.img` and
  `/tmp/x.qcow2` after.
- Probes in the same line: `ykman --version`, `python3 -c 'import cryptography'`,
  `gpg-connect-agent "scd getinfo reader_list" /bye` (after `mkdir -p -m700 /root/.gnupg`).

## USB devices (extra args, every platform)

`-device usb-ccid` (reader, no card), `-device usb-kbd` (gives /dev/hidraw0), a stick:
`$Q/make-fat-stick image/stick/stick.img 128M` (MBR+FAT32; path under $HOME), then
`-drive if=none,id=stick,file=<copy>,format=raw -device usb-storage,drive=stick` (copy the stick too; it is
/dev/sda, /dev/sda1). There is no emulated smart card or U2F device.

## A real YubiKey (needs the user: give them the command)

macOS gives only root the key's interfaces, `sudo` asks the user's PIV PIN (tickets are per terminal), and
the key must not be the one used for sudo.
1. `$Q/usb-host-info 1050:` lists bus, address, port. Two keys share `1050:0406`: unplug one, or a key behind
   a hub has a longer port path.
2. Select by bus and PORT, never address (it changes after every run): `-device usb-host,hostbus=2,hostport=1.1`.
3. `$Q/qemu-check --print KEY "-device usb-host,hostbus=2,hostport=1.1"`; the user runs it under `sudo`.
4. In the guest, read-only commands only (no `ykman ... reset`, no keygen): `mkdir -p -m700 ~/.gnupg; gpg
   --card-status`, `fido2-token -I /dev/hidraw0`, `ykman info`.

Ignore 14 lines `libusb_kernel_driver_active: -5 [NOT_FOUND]` (QEMU probes 16 interface slots, the key has 2).
`libusb_detach_kernel_driver: -3 [ACCESS]` and `can't set config #1, error -32` mean not root, not passed
through. A real key behind pi0's dwc2 aborts QEMU (`!usb_packet_is_inflight`, a dwc2 model bug) on the first
transfer: `fido2-token -L` and `gpg --card-status` both trigger it. The pi0 key can only be tried on the Pi; virt's
`qemu-xhci` carries it (tested). In the Terminal panel a fresh fish tab swallows its first command (a 10 s terminal-query
wait); `set -Ua fish_features no-query-term` fixes it, and is the user's configuration.

## Prompts

`pinentry-tty` asks on the console and an expect script can answer: source `boot.tcl` (boots and logs in), run
it with `EXPECT_SCRIPT=`, print `QEMU_CHECK_BEGIN` and `QEMU_CHECK_END` around the output to show. Example:
`examples/pinentry-import.exp`. Agents never type real PINs, only those of test keys.

## Traps

- "Failed to get write lock": an earlier QEMU still holds the overlay or stick. `ps aux | grep '[q]emu-system'`,
  then `pkill -f 'qemu-system.*<copy>'` (SIGTERM, throwaway copies only: `-9` corrupted a btrfs once).
- Login: wait for the glob `login:`, send `root`, answer `Password:` with `root`; skipping it hangs silently.
  Never wait twice for one marker.
- Keep expect in the FOREGROUND with `TIMEOUT` below the tool's 600 s, so failures print: backgrounded expect hung
  QEMU repeatedly. Builds are the long things; those go in the background. Redirect to files, not `| tail`.
- Tcl evaluates `$` and `[` in double-quoted `send` strings: type a guest `$(...)` as `\$(...)`. Guest markers
  come from the guest, typed from split strings (`QEMU_CHECK''_END`), never matched against `send`'s echo.
  `log_user 0` also empties `log_file`.
- Strip console escapes (`sed 's/\x1b\[[0-9;?]*[a-zA-Z]//g'`); never mirror raw console output to a live
  terminal: it answers the console's queries into the guest.
- Deriving a script from a working one by text replacement: ASSERT it matched (`python3 -I`, `assert old in s`).
  `sed -i ''` on the GNU sed here and non-matching regexes are silent no-ops (they gave a vacuous pass).
- After changing a recipe, delete its archive and rebuild, or you boot the old package.
- Platform files make `QEMU` readonly, so `QEMU=echo ./lfs qemu` is not a dry run: use `--print`.

## What QEMU cannot tell

The real firmware's answer to the USB power-domain request, OTG adapter and ID-pin host mode, current draw, SD
speed and DMA, real timing (TCG is not an ARM1176; an accelerated guest is not a slow board), and every PIN or
touch path. Say which of these a result leaves open.
