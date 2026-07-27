#!/bin/sh
# E1 of the end-to-end self-host proof (docs/design/e2e-cross.md): assemble
# the systemd-busybox-virt+9p+loop BUILDER image from a pristine state, container-side.
# Invoked by tests/e2e/run.sh when image/systemd-busybox-virt+9p+loop.img doesn't exist.
#
# The builder is a bootable-systemd-busybox virt system (CAPS="9p loop") whose image
# tree additionally carries the full build tool payload — the native
# toolchain plus every build tool the in-guest E2/E3 cross-build needs —
# installed as ordinary target packages into the same merge tree the image
# is made from (self-hosting.md M1-M3 delivered these as tarballs onto a
# live guest; baking them at image-build time is the scripted equivalent).
#
# It also runs the container-side pi0 baseline (system build + GnuPG
# family): the builder guest has NO network (CAPS has no `network`), so
# every source it will compile — the rpi kernel fork, the gnupg family —
# must already sit in the hash-verified download/ mirror (a host bind,
# shared to the guest over 9p) before the guest boots. The container build
# is the proven fetch path, and doubles as a regression baseline; the guest
# still builds everything itself from source into its own /var/lfs.
set -eu
cd "$(dirname "$0")/../.."

echo "e1: [1/6] Debian bootstrap - cross-toolchain (tools bootstrap)"
PLATFORM=virt docker compose run --build --rm bootstrap ./lfs tools bootstrap

echo "e1: [2/6] scratch container - temp tools + build tool set (tools build)"
PLATFORM=virt docker compose run --build --rm scratch ./lfs tools build

echo "e1: [3/6] builder system build (bootable-systemd-busybox, CAPS='9p loop')"
PLATFORM=virt INIT=systemd-busybox CAPS="9p loop" \
    docker compose run --rm scratch ./lfs system build

echo "e1: [4/6] bake the builder tool payload into the image tree"
# zlib+libffi first (python links both from this tree); native-toolchain =
# gmp/mpfr/mpc + binutils + gcc + make + linux#headers; then the tool set
# self-hosting.md M3 proved necessary (busybox applets are NOT enough:
# real patch/gawk/coreutils/bash/kmod), python's build-time companions
# (markupsafe/jinja2 for systemd's meson), and the image tools
# (btrfs-progs/dosfstools).
PLATFORM=virt INIT=systemd-busybox CAPS="9p loop" \
    docker compose run --rm scratch ./lfs install \
    zlib libffi native-toolchain \
    m4 bison flex bc gperf pkgconf gettext tar xz \
    gawk coreutils bash patch kmod rsync perl \
    python markupsafe jinja2 meson ninja \
    btrfs-progs dosfstools

echo "e1: [5/6] container pi0 baseline (populates the download/ source mirror"
echo "e1:       the no-network guest will build from: rpi kernel, gnupg family)"
# The arm cross-toolchain first: from pristine, TOOL_DIR carries only the
# virt (aarch64) cross tools from step [1] — without arm-*-gcc on PATH,
# autoconf's cross fallback silently degrades pi0 builds to the build-host
# `gcc` (confirmed: glibc-pi0's gen-as-const compiled arm sysdeps with the
# aarch64 compiler and died on pointer width). The build-host env inside is
# stamped, so this fast-paths straight to the arm pass1/sysroot/pass2.
PLATFORM=pi0 docker compose run --build --rm bootstrap ./lfs tools bootstrap
PLATFORM=pi0 INIT=systemd-busybox docker compose run --rm scratch ./lfs system build
PLATFORM=pi0 INIT=systemd-busybox docker compose run --rm scratch ./lfs install \
    zlib libgpg-error npth libassuan libksba libgcrypt libusb gnupg pinentry

echo "e1: [6/6] builder image build"
# IMAGE_SIZE: the guest's own /var/lfs holds a full cross-toolchain build,
# a pi0 system tree, archives and a 4g output image on top of the baked
# tool payload — the original hand-grown builder ended at 80g. Sparse file:
# only actual usage costs disk.
PLATFORM=virt INIT=systemd-busybox CAPS="9p loop" IMAGE_SIZE=64g \
    docker compose run --rm --user 0:0 scratch ./lfs image build

echo "e1: builder image ready: image/systemd-busybox-virt+9p+loop.img"
