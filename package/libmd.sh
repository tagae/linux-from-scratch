: ${package_version:=1.1.0}
: ${package_source:=https://libbsd.freedesktop.org/releases/libmd-$package_version.tar.xz}
: ${package_source_hash:=sha256:1bd6aa42275313af3141c7cf2e5b964e8b1fd488025caf2f971f43b00776b332}

# Message-digest functions (md5/sha1/... in the classic BSD API) — here
# solely as libbsd's own hard dependency (see libbsd.sh, pulled in for
# shadow's readpassphrase in bootable-systemd.sh).
prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
