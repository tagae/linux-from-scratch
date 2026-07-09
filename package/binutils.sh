: ${package_version:=2.46.1}
: ${package_source:=https://ftp.gnu.org/gnu/binutils/binutils-$package_version.tar.xz}

prepare() {
    $package_source_dir/configure \
        ${prefix:+--prefix=$prefix} \
        ${host:+--host=$host} \
        ${target:+--target=$target} \
        ${arch:+--with-arch=$arch} \
        ${float:+--with-float=$float} \
        ${fpu:+--with-fpu=$fpu} \
        ${tune:+--with-tune=$tune} \
        ${sysroot:+--with-sysroot=$sysroot} \
        ${nls:+--enable-nls=$nls} \
        ${gprofng:+--enable-gprofng=$gprofng} \
        ${werror:+--enable-werror=$werror} \
        ${new_dtags:+--enable-new-dtags=$new_dtags} \
        ${default_hash_style:+--with-default-hash-style=$default_hash_style}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
