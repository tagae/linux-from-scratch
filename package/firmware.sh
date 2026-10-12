: ${package_version:=1.20260521}
: ${package_source:=https://github.com/raspberrypi/firmware/releases/download/$package_version/raspi-firmware_$package_version.orig.tar.xz}
: ${package_source_hash:=sha256:f812f2f55efb97053c985cc285115e12caaa16f8040fe1a6f2f94666785257ac}
: ${package_description:=Raspberry Pi bootloader and GPU firmware, which start the kernel.}
: ${package_license:=LicenseRef-Broadcom-Firmware}

package_source_dir=$SOURCE_DIR/raspi-firmware-$package_version

install() {
    mkdir -pv $package_install_dir/boot
    cd $package_source_dir/boot
    # Redistributing the firmware requires its licence to come along.
    cp -v $firmware_files LICENCE.broadcom $package_install_dir/boot/
}
