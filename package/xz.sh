: ${package_version:=5.8.3}
: ${package_source:=https://github.com/tukaani-project/xz/releases/download/v$package_version/xz-$package_version.tar.xz}
: ${package_source_hash:=sha256:fff1ffcf2b0da84d308a14de513a1aa23d4e9aa3464d17e64b9714bfdd0bbfb6}

# build=: see m4.sh's copy of this guard.
: ${build:=$(gcc -dumpmachine)}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${static:+--enable-static=$static} \
        ${nls:+--enable-nls=$nls} \
        --docdir=/usr/share/doc/xz-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
