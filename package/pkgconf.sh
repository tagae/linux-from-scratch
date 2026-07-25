: ${package_version:=2.5.1}
: ${package_source:=https://distfiles.ariadne.space/pkgconf/pkgconf-$package_version.tar.xz}
: ${package_source_hash:=sha256:cd05c9589b9f86ecf044c10a2269822bc9eb001eced2582cfffd658b0a50c243}

# build=: see m4.sh's copy of this guard (SELF-HOST.md M3 target build). No
# target_sysroot_cc: pkgconf links nothing from the target tree.
: ${build:=$(gcc -dumpmachine)}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static \
        --docdir=/usr/share/doc/pkgconf-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
    ln -sfv pkgconf $package_install_dir/$prefix/bin/pkg-config
}
