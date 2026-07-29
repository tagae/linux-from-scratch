: ${package_version:=1.4.21}
: ${package_source:=https://ftp.gnu.org/gnu/m4/m4-$package_version.tar.xz}
: ${package_source_hash:=sha256:f25c6ab51548a73a75558742fb031e0625d6485fe5f9155949d6486a2408ab66}

# build=: a target build (./lfs install m4 — delivering the guest's own
# build-tool set as an archive tarball) sets host=$target via
# target_build_env; on virt/pi4, $target is the same CPU arch as this build
# host, so without an explicit, textually-different --build, autoconf's
# cross_compiling detection goes to "maybe" (see gmp.sh's copy of this same
# guard). No-op for the existing tools-phase native use (build_tools()
# presets package_install_dir, so host/build both stay unset there — plain,
# unprefixed native build, unchanged). m4 links nothing from the target
# tree, so no target_sysroot_cc is needed (unlike the gnupg family/ncdu.sh).
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
