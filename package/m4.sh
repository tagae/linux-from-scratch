: ${package_version:=1.4.21}
: ${package_source:=https://ftp.gnu.org/gnu/m4/m4-$package_version.tar.xz}
: ${package_source_hash:=sha256:f25c6ab51548a73a75558742fb031e0625d6485fe5f9155949d6486a2408ab66}

# build=: when host is a target triplet of the same CPU arch as the build
# machine, an explicit, textually different --build keeps autoconf's
# cross_compiling detection from going to "maybe" (see gmp.sh's copy of this
# same guard).
: ${build:=$(gcc -dumpmachine)}

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
