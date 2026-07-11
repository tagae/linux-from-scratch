: ${package_version:=20260529}
: ${package_source:=https://github.com/Mic92/iana-etc/releases/download/$package_version/iana-etc-$package_version.tar.gz}

install() {
    mkdir -pv $package_install_dir/etc
    install -v -m644 $package_source_dir/services  $package_install_dir/etc/
    install -v -m644 $package_source_dir/protocols $package_install_dir/etc/
}
