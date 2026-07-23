: ${package_version:=3.3}
: ${package_source:=https://ftpmirror.gnu.org/gperf/gperf-$package_version.tar.gz}
: ${package_source_hash:=sha256:fd87e0aba7e43ae054837afd6cd4db03a3f2693deb3619085e6ed9d8d9604ad8}

# build=: see m4.sh's copy of this guard (SELF-HOST.md M3 target build). No
# target_sysroot_cc: gperf links nothing from the target tree.
: ${build:=$(gcc -dumpmachine)}

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
