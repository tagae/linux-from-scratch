: ${package_version:=4.5.2}
: ${package_source:=https://github.com/besser82/libxcrypt/releases/download/v$package_version/libxcrypt-$package_version.tar.xz}
: ${package_source_hash:=sha256:71513a31c01a428bccd5367a32fd95f115d6dac50fb5b60c779d5c7942aec071}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${hashes:+--enable-hashes=$hashes} \
        ${obsolete_api:+--enable-obsolete-api=$obsolete_api} \
        --disable-static \
        ${failure_tokens:+--enable-failure-tokens=$failure_tokens}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
