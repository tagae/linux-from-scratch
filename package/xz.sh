: ${package_version:=5.8.3}
: ${package_source:=https://github.com/tukaani-project/xz/releases/download/v$package_version/xz-$package_version.tar.xz}
: ${package_source_hash:=sha256:fff1ffcf2b0da84d308a14de513a1aa23d4e9aa3464d17e64b9714bfdd0bbfb6}
: ${package_description:=XZ and LZMA compression utilities and library.}
: ${package_license:=0BSD AND GPL-2.0-or-later}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${static:+--enable-static=$static} \
        ${nls:+--enable-nls=$nls}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
