: ${package_source:=https://github.com/raspberrypi/firmware}
: ${package_branch:=stable}

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
