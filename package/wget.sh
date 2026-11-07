: ${package_version:=1.25.0}
: ${package_source:=https://ftp.gnu.org/gnu/wget/wget-$package_version.tar.gz}
: ${package_source_hash:=sha256:766e48423e79359ea31e41db9e5c289675947a7fcf2efdcedb726ac9d0da3784}
: ${package_description:=GNU non-interactive network downloader.}
: ${package_license:=GPL-3.0-or-later}

prepare() {
    apply_patch $package_files_dir/no-sslv3.patch

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
