: ${package_version:=2.3.2}
: ${package_source:=https://download.savannah.gnu.org/releases/acl/acl-$package_version.tar.xz}
: ${package_source_hash:=sha256:97203a72cae99ab89a067fe2210c1cbf052bc492b479eca7d226d9830883b0bd}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
