: ${package_version:=4.0.0}
: ${package_source:=https://openssl.org/source/openssl-$package_version.tar.gz}

prepare() {
    # cross_arch/cross_target default to $ARCH/$target (the platform's real
    # cross target), but callers building this build-host-native (e.g. for
    # the build host's own wget, as opposed to a copy shipped to a target
    # system) pass the build host's own arch/triple instead. $ARCH/$target
    # themselves are globally readonly and can't be reassigned even via a
    # prefix assignment, hence these separate vars.
    : ${cross_arch:=$ARCH}
    : ${cross_target=$target}

    case $cross_arch in
        arm)   _ssl_target=linux-armv4 ;;
        arm64) _ssl_target=linux-aarch64 ;;
        *)     _ssl_target=linux-generic32 ;;
    esac

    # zlib-dynamic only dlopens libz at runtime (no link-time -lz), but
    # still needs zlib.h at compile time for the wrapper in
    # crypto/comp/c_zlib.c — found via the compiler's own sysroot (zlib is
    # installed into the same $TOOL_DIR/usr tree just before this).
    $package_source_dir/Configure \
        $_ssl_target \
        ${prefix:+--prefix=$prefix} \
        --openssldir=/etc/ssl \
        --libdir=lib \
        shared \
        zlib-dynamic \
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
