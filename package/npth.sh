: ${package_version:=1.8}
: ${package_source:=https://gnupg.org/ftp/gcrypt/npth/npth-$package_version.tar.bz2}
: ${package_source_hash:=sha256:8bd24b4f23a3065d6e5b26e98aba9ce783ea4fd781069c1b35d149694e90ca3e}

# gnupg's portable threads library. host/prefix/install-dir come from
# target_build_env (applied by install() for a standalone `./lfs
# install`); build= forces autoconf to treat a same-arch
# target (virt/pi4) as a cross build; target_sysroot_cc compiles against
# the target tree's own libc (see lib/package.sh).
: ${build:=$(gcc -dumpmachine)}
target_sysroot_cc

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
