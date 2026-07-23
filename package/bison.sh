: ${package_version:=3.8.2}
: ${package_source:=https://ftp.gnu.org/gnu/bison/bison-$package_version.tar.xz}
: ${package_source_hash:=sha256:9bba0214ccf7f1079c5d59210045227bcf619519840ebfa80cd3849cff5a5bf2}

# build=: see m4.sh's copy of this guard (SELF-HOST.md M3 target build).
# No target_sysroot_cc: bison links nothing from the target tree — but it
# does RUN m4 at RUNTIME (its generated parsers shell out to it), so a
# target-scenario m4 must ship alongside this package for bison to work in
# the guest.
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
