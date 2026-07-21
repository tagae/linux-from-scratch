: ${package_version:=2.6.4}
: ${package_source:=https://github.com/westes/flex/releases/download/v$package_version/flex-$package_version.tar.gz}
: ${package_source_hash:=sha256:e87aae032bf07c26f85ac0ed3250998c37621d95f8bd748b31f15b33c45ee995}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
