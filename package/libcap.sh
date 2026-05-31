: ${package_version:=2.76}
: ${package_source:=https://www.kernel.org/pub/linux/libs/security/linux-privs/libcap2/libcap-$package_version.tar.xz}

: ${prefix:=/usr}

build() {
    cd $package_source_dir
    make prefix=$package_install_dir/$prefix lib=lib
}

install() {
    cd $package_source_dir
    make prefix=$package_install_dir/$prefix lib=lib install
}
