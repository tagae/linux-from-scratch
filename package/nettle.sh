# Nettle — low-level cryptographic primitives library (symmetric ciphers/
# hashes, plus its hogweed companion library for public-key algorithms).
# Built as a target package for exactly one reason: it's GnuTLS's crypto
# backend (see package/gnutls.sh), which is in turn this project's TLS
# backend for gnupg's dirmngr (see package/gnupg.sh's header comment for
# why dirmngr needs one at all). Matches BLFS's gnutls-3.8.12 page, which
# pins this same nettle version.
: ${package_version:=3.10.2}
: ${package_source:=https://ftp.gnu.org/gnu/nettle/nettle-$package_version.tar.gz}
: ${package_source_hash:=sha256:fe9ff51cb1f2abb5e65a6b8c10a92da0ab5ab6eaf26e7fc2b675c45f1fb519b5}

# host/prefix/install-dir come from target_build_env; build= forces
# autoconf to treat a same-arch target (virt/pi4) as a cross build;
# target_sysroot_cc compiles/links against the target tree's own libc and
# the gmp installed there by depends() below — same trio every gnupg-
# family script already carries, for the same reason (see gnupg.sh).
: ${build:=$(cc -dumpmachine)}
target_sysroot_cc

depends() {
    # hogweed's bignum ops link gmp; same require()-from-depends() pattern
    # ncdu.sh uses to pull in its own leaf build dependency. No knobs
    # needed — gmp.sh's own defaults (shared, --disable-static) are
    # already exactly what a linked-shared-library consumer like this
    # wants, and host/build/prefix/CC are inherited ambiently (see
    # lib/package.sh's require()).
    require gmp
}

prepare() {
    # Plain AC_CHECK_LIB(gmp, ...)/#include <gmp.h> probes, no pkg-config
    # or *-config script involved — target_sysroot_cc's --sysroot already
    # makes -lgmp/<gmp.h> resolve against the target tree gmp installed
    # into by depends() above, so no --with-lib-path/--with-include-path
    # is needed (unlike the gnupg family's *-config-script probes, which
    # need an explicit absolute path because those resolve via $PATH,
    # not the sysroot — see libassuan.sh).
    #
    # --disable-documentation: this project's standing no-package-docs
    # policy (see e.g. libgpg-error.sh/libtasn1.sh's own --disable-doc).
    # Default is "auto" (built if makeinfo is found), so this is a
    # correctness fix, not a no-op — nothing here guarantees texinfo is
    # absent.
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static \
        --disable-documentation
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
