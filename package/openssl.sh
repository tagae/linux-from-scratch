: ${package_version:=4.0.0}
: ${package_source:=https://openssl.org/source/openssl-$package_version.tar.gz}

prepare() {
    case $ARCH in
        arm)   _ssl_target=linux-armv4 ;;
        arm64) _ssl_target=linux-aarch64 ;;
        *)     _ssl_target=linux-generic32 ;;
    esac

    $package_source_dir/Configure \
        $_ssl_target \
        ${prefix:+--prefix=$prefix} \
        --openssldir=/etc/ssl \
        --libdir=lib \
        shared \
        zlib-dynamic \
        CROSS_COMPILE=$target-
}

build() {
    make
}

install() {
    make DESTDIR=$package_install_dir install_sw install_ssldirs
    rm -fv $package_install_dir/$prefix/lib/libcrypto.a \
           $package_install_dir/$prefix/lib/libssl.a
}
