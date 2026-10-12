: ${package_version:=1.20260521}
: ${package_source:=https://github.com/raspberrypi/firmware/archive/refs/tags/$package_version/firmware-$package_version.tar.gz}
: ${package_source_hash:=sha256:b900de58571920a306ab2d1296500499d0744451dbefda0c76b79e652bb71cb7}
: ${package_description:=Raspberry Pi bootloader and GPU firmware, which start the kernel.}
: ${package_license:=LicenseRef-Broadcom-Firmware}

install() {
    mkdir -pv $package_install_dir/boot
    cd $package_source_dir/boot
    # Redistributing the firmware requires its licence to come along.
    cp -v $firmware_files LICENCE.broadcom $package_install_dir/boot/
}
