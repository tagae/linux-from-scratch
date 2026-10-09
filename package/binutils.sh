: ${package_version:=2.46.1}
: ${package_source:=https://sourceware.org/pub/binutils/releases/binutils-$package_version.tar.xz}
: ${package_source_hash:=sha256:e127a709cba24c76de8936cb7083dd768f28cd37eb010492e2f19b71eb1294e4}
: ${package_description:=GNU assembler, linker and binary utilities.}
: ${package_license:=GPL-3.0-or-later}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${target:+--target=$target} \
        ${arch:+--with-arch=$arch} \
        ${float:+--with-float=$float} \
        ${fpu:+--with-fpu=$fpu} \
        ${tune:+--with-tune=$tune} \
        ${prefix:+--prefix=$prefix} \
        ${sysroot:+--with-sysroot=$sysroot} \
        ${nls:+--enable-nls=$nls} \
        ${shared:+--enable-shared=$shared} \
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
