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

echo "### e2e guest-build: builder-guest tool completions"
# The base builder image's live tools are insufficient to cross-build the
# pi0 system + image; overlay the correct target-built ones from the 9p
# archive share (version-globbed so a package bump doesn't break this):
#   zlib        - runtime dep of btrfs (below) and Python's zlib module
#   python      - TOOL_DIR's build-time python has no zlib module; the virt
#                 SYSTEM python does, and systemd's meson needs it
#   kmod        - busybox's depmod stub has no `-b`, which the kernel's own
#                 `make modules_install` requires
#   btrfs-progs - mkfs.btrfs for `image build`
for pkg in zlib python kmod btrfs-progs; do
    f=$(ls archive/virt/${pkg}-virt-*.tar.xz 2>/dev/null | head -1)
    [ -n "$f" ] || { echo "### missing target archive for $pkg"; exit 1; }
    echo "###   unarchive $f -> /"
    LFS_PHASE=guest ./lfs unarchive "$f" /
done
# dosfstools has no delivered archive (mkfs.fat for the pi FAT boot
# partition) - build it natively for the guest's own arch and merge into /.
echo "###   native install dosfstools"
LFS_PHASE=guest ./lfs install dosfstools

echo "### e2e guest-build: E2 - guest builds its own aarch64->arm cross-toolchain"
LFS_PHASE=guest PLATFORM=pi0 ./lfs tools bootstrap

echo "### e2e guest-build: E3 - cross-compile the pi0 system"
LFS_PHASE=guest PLATFORM=pi0 INIT=systemd ./lfs system build

echo "### e2e guest-build: E3 - cross-compile the GnuPG family for pi0"
LFS_PHASE=guest PLATFORM=pi0 INIT=systemd ./lfs install \
    zlib libgpg-error npth libassuan libksba libgcrypt libusb gnupg pinentry

echo "### e2e guest-build: E3 - build the pi0 image"
LFS_PHASE=guest PLATFORM=pi0 INIT=systemd ./lfs image build

echo "### e2e guest-build: copy artifacts out over 9p (never clobbering the"
echo "### container-built image/pi0.img or work/boot/pi0/)"
cp /var/lfs/image/pi0.img /mnt/lfs/image/e2e-pi0.img
mkdir -p /mnt/lfs/work-e2e/boot/pi0
cp /var/lfs/work/boot/pi0/kernel.img /mnt/lfs/work-e2e/boot/pi0/kernel.img
cp /var/lfs/work/boot/pi0/*.dtb      /mnt/lfs/work-e2e/boot/pi0/ 2>/dev/null || true
sync

echo E2E_GUEST_BUILD_OK
