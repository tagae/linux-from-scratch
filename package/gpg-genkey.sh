: ${package_version:=0.1.0}
: ${package_description:=Makes OpenPGP keys for security keys in memory, and exports them to a USB stick.}
: ${package_license:=MIT}

install() {
    cd $package_install_dir
    cp -rv $package_files_dir/usr .
}
