# Raspberry Pi bootloader/GPU firmware (bootcode.bin/start.elf/fixup.dat +
# device-tree overlays): real Pi hardware's SoC boot ROM reads these
# straight off the FAT boot partition before Linux ever runs (loads
# bootcode.bin, which loads start.elf, which loads kernel.img per
# config.txt — see package/boot.sh's #config component) — QEMU needs none
# of this (it loads -kernel/-dtb directly), so this package only matters
# for real hardware, but is regression-neutral to install unconditionally
# wherever DTB is set.
#
# Pinned to an immutable GitHub release TAG tarball, not the floating
# "stable" branch this package used before: same reasoning as linux.sh's
# own kernel-tag pin (kernel-config.md) — a branch head moves, so a
# `git clone --branch stable` checkout's content silently changes out from
# under a supposedly-reproducible build, with no hash to catch it. The
# archive/refs/tags/$version/firmware-$version.tar.gz form (extra filename
# segment after the ref) is the same trick linux.sh's
# _raspberrypi_kernel_source uses: GitHub ignores it for ref resolution but
# uses it to name the download, so $DOWNLOAD_DIR/firmware-$version.tar.gz
# lines up with package_source_dir=$SOURCE_DIR/firmware-$version (the
# tarball's own top-level dir) without any extra renaming.
: ${package_version:=1.20260521}
: ${package_source:=https://github.com/raspberrypi/firmware/archive/refs/tags/$package_version/firmware-$package_version.tar.gz}
: ${package_source_hash:=sha256:b900de58571920a306ab2d1296500499d0744451dbefda0c76b79e652bb71cb7}

install() {
    mkdir -pv $package_install_dir/boot

    # Copy bootloader files
    cp -v $package_source_dir/boot/bootcode.bin $package_install_dir/boot/ 2>/dev/null || true
    cp -v $package_source_dir/boot/start.elf $package_install_dir/boot/
    cp -v $package_source_dir/boot/fixup.dat $package_install_dir/boot/

    # Overlays
    mkdir -pv $package_install_dir/boot/overlays
    cp -rv $package_source_dir/boot/overlays/. $package_install_dir/boot/overlays/
}
