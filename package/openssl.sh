: ${package_version:=4.0.0}
: ${package_source:=https://openssl.org/source/openssl-$package_version.tar.gz}

prepare() {
    # cross_arch/cross_target default to $ARCH/$target (the platform's
    # real cross target), but callers building this host-native (e.g. for
    # the build host's own wget, as opposed to a copy shipped to a target
    # system) explicitly pass cross_arch=<build host arch> cross_target=""
    # for a native build. $ARCH/$target themselves are globally readonly
    # and can't be reassigned even via a prefix assignment, hence these
    # separate vars.
    : ${cross_arch:=$ARCH}
    : ${cross_target=$target}

    case $cross_arch in
        arm)   _ssl_target=linux-armv4 ;;
        arm64) _ssl_target=linux-aarch64 ;;
        *)     _ssl_target=linux-generic32 ;;
    esac

    # zlib-dynamic only dlopens libz at runtime (no link-time -lz, so no
    # --with-zlib-lib needed), but still needs zlib.h at compile time to
    # build the wrapper in crypto/comp/c_zlib.c. This is only ever built
    # host-native, straight after `install zlib` into the same $TOOL_DIR/usr
    # tree (see lib/tools.sh), which isn't on the build container's own
    # default include search path. (--with-zlib-lib was tried and reverted:
    # it feeds -L$TOOL_DIR/usr/lib into CNF_LDFLAGS, used by every shared
    # lib link, which inside the *bootstrap* container makes ld resolve
    # TOOL_DIR's own libc.so linker script instead of the container's own —
    # see _tools_set_rtld_ldflags in lib/tools.sh for the same bug.)
    $package_source_dir/Configure \
        $_ssl_target \
        ${prefix:+--prefix=$prefix} \
        --openssldir=/etc/ssl \
        --libdir=lib \
        shared \
        no-tests \
        zlib-dynamic \
        --with-zlib-include=$TOOL_DIR/usr/include \
        CROSS_COMPILE=${cross_target:+$cross_target-}
}

build() {
    make
}

install() {
    make DESTDIR=$package_install_dir install_sw install_ssldirs
    rm -fv $package_install_dir/$prefix/lib/libcrypto.a \
           $package_install_dir/$prefix/lib/libssl.a
}
