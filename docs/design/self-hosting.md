Self-hosting: LFS builds LFS
============================

Achieved 2026-07-24: the booted virt guest natively built the complete
system and a bootable image, and the host booted the result under the
standard harness; the pi0 capstone proved tarball delivery on an
emulated 512 MB ARMv6 with no host conveniences at all.

Architecture
------------

* **The guest is a third build phase** (build-phases.md): `LFS_PHASE=
  guest` on a booted system, project mounted at /mnt/lfs over 9p, heavy
  build state guest-local under /var/lfs, downloads from the shared
  hash-verified cache (offline-capable by design).
* **The toolchain is delivered, not rebuilt**: `native-toolchain` (a
  meta-package: linux#headers, gmp/mpfr/mpc, binutils, gcc, make) is
  cross-built host==target in the container and reaches the guest as
  archive tarballs replayed per ORDER (packaging.md). Generation N
  builds generation N+1 — the same lineage as Debian seeding the
  original cross toolchain. gcc.sh/binutils.sh carry host==target
  guards: the `cc` symlink, lib64→lib relocation (aarch64), and
  `$target-*` prefixed tool names.
* **Busybox applets are not enough for system builds** — real patch
  (fuzz matching), gawk, coreutils (`ln --force`), bash (`#!/bin/bash`
  codegen), and kmod (`depmod -b`) ship as target tarballs, alongside
  the full tool set (bison flex bc gperf m4 pkgconf rsync gettext
  tar xz python meson ninja perl).
* **A guest `system build`** applies the target scenario (separate
  guest-local tree, host=$target → the native prefixed toolchain) —
  ad-hoc `./lfs install <pkg>` merges into the live `/` instead.
  Guest-specific accommodations, each guarded: TOOL_DIR-based knobs are
  existence-guarded (native compiled-in /usr defaults are correct on a
  booted system), systemd's meson runs with needs_exe_wrapper=false,
  ca-certificates installs from its cross-built tarball, image build
  falls back from kpartx to `losetup -P` (real devtmpfs), btrfs-progs
  is a target package, and the `loop` capability provides loop devices.
* **The builder guest** is `CAPS="9p loop"` booted with
  `QEMU_EXTRA="-smp 8 -m 8192"` and a 16 GB image (`IMAGE_SIZE=16g`).
  Finished artifacts are copied out over 9p (`image/selfhost-virt.img`,
  guest-built kernel under `work/boot-selfhost/`); the host boots them
  via WORK_DIR override + an explicit image argument to `./lfs qemu`.
* **pi0 (no virtio → no 9p/network)**: the payload ships INSIDE the
  image (`/srv/lfs`: tarballs + ORDER + project machinery + sources);
  the guest self-installs by plain `tar xf` and builds natively under
  TCG (`image/selfhost-pi0.img` retains the /var/lfs build state as
  evidence).

Residuals
---------

Real-hardware SD boot still needs `install firmware`
(gnupg-appliance.md); native gcc-scale compiles are virt-only (TCG is
impractical for that, and doesn't need to be practical — delivery is by
tarball).
