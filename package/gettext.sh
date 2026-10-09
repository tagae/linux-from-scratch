: ${package_version:=1.0}
: ${package_source:=https://ftp.gnu.org/gnu/gettext/gettext-$package_version.tar.xz}
: ${package_source_hash:=sha256:71132a3fb71e68245b8f2ac4e9e97137d3e5c02f415636eb508ae607bc01add7}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static \
        --docdir=/usr/share/doc/gettext-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
