#!/bin/sh
# E2 + E3 of the end-to-end self-host proof, run INSIDE the virt builder
# guest (see docs/design/e2e-cross.md). The guest — which already carries a
# native toolchain + the full build tool set — builds its OWN aarch64->arm
# cross-toolchain and then cross-compiles a complete pi0 image including the
# GnuPG family, copying the result back to the host over the 9p share.
#
# Invoked by tests/e2e/builder.exp as `sh /mnt/lfs/tests/e2e/guest-build.sh`.
# POSIX sh (busybox ash compatible): the builder guest is an LFS system.
#
# Idempotent: re-running against a warm builder guest fast-paths every
# already-built package (that is exactly how the E2-E4 drivers are validated
# without a from-pristine rebuild).
set -eu

# Emit an explicit failure sentinel on any errexit abort; the OK sentinel is
# reached only if every step below succeeded. builder.exp matches these.
trap 'st=$?; [ "$st" -eq 0 ] || echo "E2E_GUEST_BUILD_FAIL (exit $st)"' EXIT

cd /mnt/lfs   # the project, mounted over 9p (mount_tag=lfs)

echo "### e2e guest-build: builder-guest tool completions (probe-first)"
# A freshly-assembled E1 builder image (tests/e2e/e1-builder-image.sh) bakes
# all of these in, so every probe passes and nothing happens. Against an
# older/hand-grown builder image, each missing capability is overlaid from
# the target-built virt archive on the 9p share (or built natively for
# dosfstools). Probes test the CAPABILITY, not the package:
#   libz.so.1     - runtime dep of btrfs-progs and Python's zlib module
#   python3+zlib  - systemd's meson imports zlib at build time
#   real depmod   - busybox's stub has no `-b`, which the kernel's own
#                   `make modules_install` requires
#   mkfs.btrfs    - formats the root filesystem in `image build`
#   mkfs.fat      - formats the pi FAT boot partition in `image build`
overlay() {
    # Prefer the builder's OWN key's archives (the only ones a from-pristine
    # E1 produces), then plain virt (present on older/hand-grown setups).
    f=$(ls "archive/systemd-virt+9p+loop/$1"-*.tar.xz archive/systemd-virt/$1-systemd-virt-*.tar.xz \
        2>/dev/null | head -1)
    if [ -z "$f" ]; then
        echo "### FATAL: $1 capability missing and no archive fallback"
        exit 1
    fi
    echo "###   unarchive $f -> /"
    ./lfs unarchive "$f" / || exit 1
}
[ -e /usr/lib/libz.so.1 ]             || overlay zlib
python3 -c 'import zlib' 2>/dev/null  || overlay python
depmod -V 2>/dev/null | grep -q kmod  || overlay kmod
command -v mkfs.btrfs >/dev/null 2>&1 || overlay btrfs-progs
if ! command -v mkfs.fat >/dev/null 2>&1; then
    echo "###   native install dosfstools"
    ./lfs install dosfstools
fi

echo "### e2e guest-build: E2 - guest builds its own aarch64->arm cross-toolchain"
PLATFORM=pi0 ./lfs tools bootstrap

echo "### e2e guest-build: E3 - cross-compile the pi0 system"
PLATFORM=pi0 INIT=systemd ./lfs system build

echo "### e2e guest-build: E3 - cross-compile the GnuPG family for pi0"
PLATFORM=pi0 INIT=systemd ./lfs install \
    zlib libgpg-error npth libassuan libksba libgcrypt libusb gnupg pinentry

echo "### e2e guest-build: E3 - build the pi0 image"
PLATFORM=pi0 INIT=systemd ./lfs image build

echo "### e2e guest-build: copy artifacts out over 9p"
# The image gets its own e2e- name (the container-built pi0.img, when one
# exists, is a distinct artifact worth keeping); the kernel/dtb go to the
# CANONICAL work/boot/systemd-pi0/ — deliberately superseding the container
# baseline's copy there, so ./lfs qemu boots the guest-built kernel with
# no WORK_DIR override. The errexit trap + the OK sentinel below are what
# guarantee these copies actually happened.
cp /var/lfs/image/systemd-pi0.img /mnt/lfs/image/e2e-pi0.img
mkdir -p /mnt/lfs/work/boot/systemd-pi0
cp /var/lfs/work/boot/systemd-pi0/kernel.img /mnt/lfs/work/boot/systemd-pi0/kernel.img
cp /var/lfs/work/boot/systemd-pi0/*.dtb      /mnt/lfs/work/boot/systemd-pi0/ 2>/dev/null || true
sync

echo E2E_GUEST_BUILD_OK
