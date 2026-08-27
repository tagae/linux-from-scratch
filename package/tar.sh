: ${package_version:=1.35}
: ${package_source:=https://ftp.gnu.org/gnu/tar/tar-$package_version.tar.xz}
: ${package_source_hash:=sha256:4d62ff37342ec7aed748535323930c7cf94acf71c3591882b26a7ea50f3edc16}

# build=: see m4.sh's copy of this guard (the target build that ships this
# tool to the guest as an archive tarball — GNU tar is the other
# archive-parity enabler, alongside xz.sh). No target_sysroot_cc: tar
# shells out to external gzip/bzip2/xz rather than linking their libraries
# directly, so nothing from the target tree is linked at build time either.
: ${build:=$(gcc -dumpmachine)}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${nls:+--enable-nls=$nls}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
