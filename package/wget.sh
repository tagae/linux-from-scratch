: ${package_version:=1.25.0}
: ${package_source:=https://ftpmirror.gnu.org/wget/wget-$package_version.tar.gz}

prepare() {
    # wget-1.25.0 still references SSLv3_client_method, which OpenSSL 4.0
    # dropped entirely (without continuing to define OPENSSL_NO_SSL3_METHOD
    # to guard against it, as older OpenSSL did). SSLv3 is deprecated and
    # insecure regardless, so just drop the dead code path.
    sed -i '/meth = SSLv3_client_method ();/d' $package_source_dir/src/openssl.c

    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --with-ssl=openssl \
        ${nls:+--enable-nls=$nls}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
