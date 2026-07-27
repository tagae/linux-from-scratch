Simplification opportunities
============================

Originally a full-project review of 2026-07-19; pruned 2026-07-25, and
again 2026-07-27 after a simplification pass resolved most of the list:
the 12 genuinely-unused package scripts were deleted (restore from git
history if a staged BLFS addition ever needs one back — readline for a
future pinentry-curses was the noted case), the dead `kernel=` platform
variable and root TODO file went with them, lib/image.sh's unmount
duplication collapsed into one cleanup chain, the qemu command moved to
lib/qemu.sh, CAPS was folded into the parameterized Makefile rules
(deleting the network-* special case), reinstall-tools/-system were
keyed and their stamp deletion fixed, README/CONTRIBUTING/`lfs help`
were refreshed, lib/tools.sh's duplicated gmp/mpfr/mpc and full-gcc
blocks became _tools_gcc_prereqs/_tools_install_full_gcc, and has_cap()
replaced every hand-rolled `case " $CAPS "` membership test.

Still open
----------

1. **`Dockerfile.bootstrap-alpine`** — present, referenced by nothing;
   the bootstrap moved to Debian/glibc long ago. Kept deliberately for
   now.

2. **`defconfig` defined twice per Pi platform** — readonly in
   `lib/platform/pi*.sh` (wins) and again as `: ${defconfig:=...}` in
   `package/linux.sh`'s per-platform case (always shadowed, dead).
   Kept deliberately for now.

3. **The twin systemd umbrellas** (`bootable-systemd-busybox.sh` /
   `bootable-systemd-coreutils.sh`) are ~95% identical, diverging only
   in the userland/login block. Deliberate explicitness (three explicit
   umbrellas was a considered decision) — revisit only if maintaining
   the shared parts twice starts biting.

4. **pass1-native builds gcc's bundled gmp/mpfr/mpc** — the one gcc
   build that doesn't go through `_tools_gcc_prereqs` (lib/tools.sh),
   despite the "one code path on every build host" intent of that
   helper. Making it uniform changes what actually gets built (a
   behavior decision, not a refactor) — see the helper's comment.

Correctness note (unchanged)
----------------------------

`boot.sh` writes cmdline.txt/config.txt with pi0-hardcoded values
(PL011 base, `root=/dev/mmcblk0p2`, `arm_64bit=0`, the bcm2835_pm
blacklist) but installs them for every DTB platform — wrong for a real
pi4/pi5 boot, invisible under QEMU (which loads kernels directly).
Right for the pi0 appliance use case, so low priority until pi4/pi5
real-hardware matters.
