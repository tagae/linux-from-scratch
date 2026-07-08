: ${package_version:=2.46.1}
: ${package_source:=https://ftp.gnu.org/gnu/binutils/binutils-$package_version.tar.xz}

: ${prefix:=/usr}
: ${sysroot:=/}
: ${gprofng:=yes}
: ${multilib:=no}
: ${nls:=yes}
: ${werror:=yes}
: ${werror:=yes}
: ${new_dtags:=no}
: ${default_hash_style=gnu}

prepare() {
    : ${build:=$($package_source_dir/config.guess)}
    : ${host:=$build}
    : ${target:=$host}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --target=$target \
        --with-sysroot=$sysroot \
        ${arch:+--with-arch=$arch} \
        ${float:+--with-float=$float} \
        ${fpu:+--with-fpu=$fpu} \
        ${tune:+--with-tune=$tune} \
        --enable-multilib=$multilib \
        --enable-nls=$nls \
        --enable-gprofng=$gprofng \
        --enable-werror=$werror \
        --enable-new-dtags=$new_dtags \
        --with-default-hash-style=$default_hash_style
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
