: ${package_version:=1.59}
: ${package_source:=https://gnupg.org/ftp/gcrypt/libgpg-error/libgpg-error-$package_version.tar.bz2}
: ${package_source_hash:=sha256:a19bc5087fd97026d93cb4b45d51638d1a25202a5e1fbc3905799f424cfa6134}

# Base of the gnupg family (see GNUPG-YUBIKEY.md) — install this first.
#
# Bumped 1.51 -> 1.59 alongside the rest of the family's BLFS gnupg-2.5.17
# alignment: BLFS's own gnupg page doesn't pin this one, but libgcrypt-1.12.0
# does — its configure hard-requires "GPG Error - version >= 1.56" (confirmed
# empirically: 1.51 fails libgcrypt's configure with exactly that message),
# and BLFS's own libgcrypt-1.12.0 page lists libgpg-error-1.59 as its
# required dependency. Matching that pairing rather than picking the bare
# minimum 1.56.
# host/prefix/install-dir come from target_build_env (applied by install()
# for a standalone `./lfs install`); build= forces autoconf to treat a
# same-arch target (virt/pi4) as a cross build; target_sysroot_cc compiles
# against the target tree's own libc (see lib/package.sh).
: ${build:=$(gcc -dumpmachine)}
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
