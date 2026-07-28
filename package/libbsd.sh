: ${package_version:=0.12.2}
: ${package_source:=https://libbsd.freedesktop.org/releases/libbsd-$package_version.tar.xz}
: ${package_source_hash:=sha256:b88cc9163d0c652aaf39a99991d974ddba1c3a9711db8f1b5838af2a14731014}

# BSD utility functions on glibc — here solely for readpassphrase(3),
# which shadow's login/passwd hard-require and glibc doesn't provide
# (see bootable-systemd.sh).
# build=: see gmp.sh's copy of this guard. target_sysroot_cc: links the
# target tree's own libmd (installed just before this by the same
# caller) — same opt-in the gnupg family carries.
: ${build:=$(gcc -dumpmachine)}
target_sysroot_cc

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${host:+--with-sysroot=$INSTALL_DIR/$SYSTEM_KEY} \
        --disable-static
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
