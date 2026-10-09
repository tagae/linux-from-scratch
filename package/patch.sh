: ${package_version:=2.8}
: ${package_source:=https://ftp.gnu.org/gnu/patch/patch-$package_version.tar.xz}
: ${package_source_hash:=sha256:f87cee69eec2b4fcbf60a396b030ad6aa3415f192aa5f7ee84cad5e11f7f5ae3}
: ${package_description:=GNU utility to apply diffs to files.}
: ${package_license:=GPL-3.0-or-later}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
