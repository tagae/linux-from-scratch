: ${package_version:=1.7}
: ${package_source:=https://gnupg.org/ftp/gcrypt/npth/npth-$package_version.tar.bz2}
: ${package_source_sha256:=8589f56937b75ce33b28d312fccbf302b3b71ec3f3945fde6aaa74027914ad05}

# gnupg's portable threads library (see GNUPG-YUBIKEY.md). host/prefix/
# install-dir come from target_build_env (applied by install() for a
# standalone `./lfs install`); build= forces autoconf to treat a same-arch
# target (virt/pi4) as a cross build; target_sysroot_cc compiles against
# the target tree's own libc (see lib/package.sh).
: ${build:=$(cc -dumpmachine)}
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
