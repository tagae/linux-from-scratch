: ${package_version:=20260529}
: ${package_source:=https://github.com/Mic92/iana-etc/releases/download/$package_version/iana-etc-$package_version.tar.gz}
: ${package_source_hash:=sha256:4100d8c4e8653701972e68f8326be75ecb0aa08b374e57553b0d114c6b7acdf8}

install() {
    mkdir -pv $package_install_dir/etc
    install -v -m644 $package_source_dir/services  $package_install_dir/etc/
    install -v -m644 $package_source_dir/protocols $package_install_dir/etc/
}
