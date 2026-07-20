: ${package_version:=1.51}
: ${package_source:=https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-$package_version.tar.bz2}
: ${package_source_sha256:=be0f1b2db6b93eed55369cdf79f19f72750c8c7c39fc20b577e724545427e6b2}

# Base of the gnupg family (see GNUPG-YUBIKEY.md) — install this first.
# host/prefix/install-dir come from target_build_env (applied by install()
# for a standalone `./lfs install`); build= forces autoconf to treat a
# same-arch target (virt/pi4) as a cross build; target_sysroot_cc compiles
# against the target tree's own libc (see lib/package.sh).
: ${build:=$(cc -dumpmachine)}
target_sysroot_cc

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-doc
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
