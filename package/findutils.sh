: ${package_version:=4.11.0}
: ${package_source:=https://ftp.gnu.org/gnu/findutils/findutils-$package_version.tar.xz}
: ${package_source_hash:=sha256:bfd19cb06cc71f3352d567e90284d8cdac02ac89774bbeadf0b533b0c11432fd}
: ${package_description:=GNU file search utilities.}
: ${package_license:=GPL-3.0-or-later}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${localstatedir:+--localstatedir=$localstatedir} \
        ${nls:+--enable-nls=$nls}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
