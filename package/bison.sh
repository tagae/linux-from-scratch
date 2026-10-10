: ${package_version:=3.8.2}
: ${package_source:=https://ftp.gnu.org/gnu/bison/bison-$package_version.tar.xz}
: ${package_source_hash:=sha256:9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2}
: ${package_description:=GNU parser generator.}
: ${package_license:=GPL-3.0-or-later AND GPL-3.0-or-later WITH Bison-exception-2.2}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${nls:+--enable-nls=$nls} \
        ${relocatable:+--enable-relocatable=$relocatable}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
