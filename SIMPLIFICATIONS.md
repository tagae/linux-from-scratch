Simplification opportunities
============================

Originally a full-project review of 2026-07-19; pruned 2026-07-25 to
what is still true (resolved items removed: the archive machinery is now
fully implemented — see docs/design/packaging.md — and the README was rewritten,
though it has gone stale again, see below).

Dead code that can be deleted outright
--------------------------------------

1. **14 unused package scripts** (re-audited 2026-07-25): `acl`,
   `attr`, `dbus`, `elfutils`, `iana-etc`, `iproute2`, `less`,
   `libxcrypt`, `man-pages`, `procps-ng`, `psmisc`, `readline`,
   `shadow`, `zstd`. No build phase installs them; references are
   comments or disabled flags. (Since the original review, `libffi`
   became load-bearing — the CA-trust chain — and `expat` was deleted;
   the self-host tool set consumed most of the rest of the old list:
   bison/flex/bc/gperf/python/meson/ninja/tar/xz/gettext/rsync/m4/perl/
   pkgconf/patch/gawk/coreutils/bash are all genuinely used now.)
   Caveat unchanged: if these are staged future BLFS additions, keep;
   `readline` in particular would serve a future pinentry-curses.

2. **`Dockerfile.bootstrap-alpine`** — still present, still referenced
   by nothing; the bootstrap moved to Debian/glibc long ago.

3. **The `kernel=` variable in `lib/platform/pi*.sh`** (`kernel`,
   `kernel8`, `kernel_2712`) is unused — `boot.sh`'s config.txt
   hardcodes `kernel=kernel.img`, which is what `linux.sh` normalizes
   to anyway.

4. **`defconfig` defined twice per Pi platform** — readonly in
   `lib/platform/pi*.sh` (wins) and again as `: ${defconfig:=...}` in
   `package/linux.sh`'s per-platform case (always shadowed, dead).

Duplication
-----------

5. **`lib/image.sh`**: `unmount_all` and `unmount_partitions` still
   contain the same umount block verbatim; `image_cleanup` re-implements
   the pair again. One call chain would do.

Staleness
---------

6. **README.md and CONTRIBUTING.md predate the second half of the
   project**: no mention of capabilities (CAPS: network/9p/usb/loop/
   amnesia), the archive/tarball system, self-hosting (guest phase,
   builder guest, selfhost images), the gnupg family/appliance, or the
   `unarchive` verb. The quick-start targets they do document still
   work.

7. **`lfs help` text**: the platform list omits `virt` (the default),
   and "`qemu [FILE]  Boot image in QEMU (creates image if needed)`" is
   wrong — it bails if kernel/image are missing, and doesn't mention
   INIT/CAPS/USB_DISK/QEMU_EXTRA.

Semantics drift worth rethinking
--------------------------------

8. **`reinstall-tools`/`reinstall-system`** still delete every
   platform's stamps indiscriminately and rebuild only virt; in the
   per-SYSTEM_KEY world these want to be keyed (`reinstall-system-%`,
   scoped stamp deletion). Also predates capabilities entirely.

Correctness note (unchanged)
----------------------------

`boot.sh` writes cmdline.txt/config.txt with pi0-hardcoded values
(PL011 base, `root=/dev/mmcblk0p2`, `arm_64bit=0`, the bcm2835_pm
blacklist) but installs them for every DTB platform — wrong for a real
pi4/pi5 boot, invisible under QEMU (which loads kernels directly).
Right for the pi0 appliance use case, so low priority until pi4/pi5
real-hardware matters.
