: ${package_version:=4.4.1}
: ${package_source:=https://ftp.gnu.org/gnu/make/make-$package_version.tar.gz}
: ${package_source_hash:=sha256:dd16fb1d67bfab79a72f5e8390735c49e3e8e70b4945a15ab1f81ddb78658fb3}
: ${package_description:=GNU build automation tool.}
: ${package_license:=GPL-3.0-or-later}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${nls:+--enable-nls=$nls}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
