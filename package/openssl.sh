: ${package_version:=4.0.0}
: ${package_source:=https://github.com/openssl/openssl/releases/download/openssl-$package_version/openssl-$package_version.tar.gz}
: ${package_source_hash:=sha256:c32cf49a959c4f345f9606982dd36e7d28f7c58b19c2e25d75624d2b3d2f79ac}
: ${package_description:=TLS and general-purpose cryptography toolkit.}
: ${package_license:=Apache-2.0}

prepare() {
    $package_source_dir/Configure \
        ${prefix:+--prefix=$prefix} \
        --openssldir=/etc/ssl \
        --libdir=lib \
        shared
}

build() {
    make
}

install() {
    make DESTDIR=$package_install_dir install_sw install_ssldirs
    rm -fv $package_install_dir/$prefix/lib/libcrypto.a \
           $package_install_dir/$prefix/lib/libssl.a
}
