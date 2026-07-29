: ${package_version:=2.46.1}
: ${package_source:=https://sourceware.org/pub/binutils/releases/binutils-$package_version.tar.xz}
: ${package_source_hash:=sha256:e127a709cba24c76de8936cb7083dd768f28cd37eb010492e2f19b71eb1294e4}

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

    # Native-for-target scenario (package/native-toolchain.sh): host==target
    # here makes binutils treat this as a native build and install only bare
    # names (ar, ld, ...) — but hand-rolled configures elsewhere (zlib's,
    # the kernel's) look for $target-prefixed names first, mirroring what
    # gcc's own install already provides for gcc (see gcc.sh). Same guard
    # target_sysroot_cc uses to identify this scenario; every other caller
    # (lib/tools.sh's pass1/pass2) leaves host unset, so this is a no-op
    # there — byte-identical tools/cross behavior.
    if [ "${host:-}" = "$target" ]; then
        local _tool
        for _tool in addr2line ar as c++filt dwp elfedit gprof ld ld.bfd \
                     ld.gold nm objcopy objdump ranlib readelf size \
                     strings strip; do
            [ -x $package_install_dir/$prefix/bin/$_tool ] || continue
            ln -sfv $_tool $package_install_dir/$prefix/bin/$target-$_tool
        done
    fi
}
