: ${package_version:=3.8.2}
: ${package_source:=https://ftp.gnu.org/gnu/bison/bison-$package_version.tar.xz}
: ${package_source_hash:=sha256:9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2}

# bison runs m4 at run time, so m4 must be installed wherever bison is.
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
