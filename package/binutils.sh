: ${package_version:=2.46.1}
: ${package_source:=https://ftpmirror.gnu.org/binutils/binutils-$package_version.tar.xz}
: ${package_source_sha256:=e127a709cba24c76de8936cb7083dd768f28cd37eb010492e2f19b71eb1294e4}

prepare() {
    # cross_target defaults to $target (the platform's real cross target —
    # every existing caller keeps working unchanged), but callers building
    # a build-host-native toolchain (used by build_tools()/Ch6 tools to
    # actually execute in the scratch container, as opposed to the
    # per-platform cross-compiler) explicitly pass cross_target="" to omit
    # --target entirely. $target itself is globally readonly and can't be
    # reassigned even via a prefix assignment, hence this separate var.
    : ${cross_target=$target}

    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${cross_target:+--target=$cross_target} \
        ${arch:+--with-arch=$arch} \
        ${float:+--with-float=$float} \
        ${fpu:+--with-fpu=$fpu} \
        ${tune:+--with-tune=$tune} \
        ${prefix:+--prefix=$prefix} \
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
