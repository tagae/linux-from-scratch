: ${package_version:=1.25.0}
: ${package_source:=https://ftp.gnu.org/gnu/wget/wget-$package_version.tar.gz}
: ${package_source_hash:=sha256:766e48423e79359ea31e41db9e5c289675947a7fcf2efdcedb726ac9d0da3784}
: ${package_description:=GNU non-interactive network downloader.}
: ${package_license:=GPL-3.0-or-later}

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
