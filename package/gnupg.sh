# Install order for the whole optional gnupg family — nothing enforces
# this automatically, since these are all invoked ad hoc via `./lfs
# install <pkg>` rather than from a dependency-ordered build phase like
# build_system():
#
#   zlib -> libgpg-error -> npth -> libassuan -> libksba -> libgcrypt ->
#   libusb -> gmp -> nettle -> libtasn1 -> gnutls -> gnupg -> pinentry
#
# Versions aligned to BLFS stable-systemd's gnupg-2.5.17 page (gnupg,
# libassuan, libgcrypt, npth, pinentry all bumped to match its tested set;
# libksba/libgpg-error/libusb are unchanged — BLFS's own page doesn't pin
# the first two at all, and libusb here is this project's own YubiKey
# addition, not one of gnupg's own required deps). gmp/nettle/libtasn1/
# gnutls are this project's own addition too, on top of BLFS's own gnupg
# page — see package/gnutls.sh — pulled in solely to give dirmngr (below)
# a TLS backend; BLFS's gnupg page doesn't need them because it always
# builds on a system with a target GnuTLS already present system-wide.
#
# Keeps gpg, gpg-agent and scdaemon; keyboxd/tofu/ldap/wks-tools/gpgtar/
# photo-viewers/doc stay disabled — still out of scope for a minimal
# embedded build (keyboxd avoids sqlite, doc avoids texinfo — this project
# doesn't build package documentation). --enable-ccid-driver lets scdaemon
# talk to a YubiKey directly over USB via libusb, no pcscd/libccid stack
# needed.
#
# --disable-dirmngr was DROPPED, and dirmngr now genuinely builds. dirmngr
# is the daemon gpg shells out to for keyserver access; the goal was
# reaching hkps:// (HTTPS) keyservers — proven end-to-end against
# keys.openpgp.org through the project's own from-scratch CA store, on a
# network-capability guest. gnupg-2.5.17's own configure.ac hard-requires
# a TLS backend (NTBTLS or GnuTLS) to build dirmngr AT ALL — there is no
# "build it, just skip HTTPS" middle ground; dirmngr's networking layer
# needs one even for plain hkp://. Without either, configure prints "***
# Neither NTBTLS nor GNUTLS available - not building dirmngr." and simply
# omits it (not a fatal error — confirmed empirically before GnuTLS was
# added: gpg/gpg-agent/scdaemon/pinentry-tty all still built and ran fine;
# no dirmngr binary existed in the install tree at all). GnuTLS
# (package/gnutls.sh) is now built ahead of gnupg in the install order
# above, and configure.ac detects it automatically via pkg-config
# (PKG_CHECK_MODULES([LIBGNUTLS], [gnutls >= 3.2]) — see
# NEED_GNUTLS_VERSION in gnupg's own configure.ac), the same
# PKG_CONFIG_LIBDIR/_SYSROOT_DIR mechanism package/systemd.sh already
# established for cross pkg-config lookups — see prepare() below.
: ${package_version:=2.5.17}
: ${package_source:=https://gnupg.org/ftp/gcrypt/gnupg/gnupg-$package_version.tar.bz2}
: ${package_source_hash:=sha256:2c1fbe20e2958fd8fb53cf37d7c38e84a900edc0d561a1c4af4bc3a10888685d}

# Links against libgpg-error/libgcrypt/libassuan/libksba/npth/gnutls, all
# already installed into $INSTALL_DIR/$SYSTEM_KEY — see libassuan.sh for why
# target_sysroot_cc and explicit --with-*-prefix flags are both needed
# (gnupg's own configure probes each dependency's own *-config/pkg-config
# script, which would otherwise happily answer with a host or toolchain
# path instead — see config.log for which one, if a wrong path ever leaks).
# gnutls itself is found via plain pkg-config rather than a *-config
# script — see the PKG_CONFIG_LIBDIR/_SYSROOT_DIR comment in prepare().
: ${build:=$(gcc -dumpmachine)}
target_sysroot_cc

prepare() {
    # GPGRT_CONFIG: see libassuan.sh's prepare() for why this absolute
    # path (rather than relying on configure's own $PATH search) is
    # needed for every package here that probes libgpg-error this way.
    #
    # CPPFLAGS: gnupg's own libusb detection (configure.ac's GNUPG_CHECK_
    # LIBUSB-equivalent inline check) never grew pkg-config support — it
    # only tries linking -lusb-1.0 (which the sysroot CC already resolves)
    # and then hunts for <libusb.h> under a short hardcoded list of *literal*
    # incdirs ("/usr/include/libusb-1.0", "/usr/local/...", "/usr/pkg/...");
    # plain -I flags aren't sysroot-adjusted the way default search paths
    # are, so none of those literal paths ever reach our sysroot. Its very
    # first candidate is "" (no -I at all, i.e. whatever CPPFLAGS already
    # holds), which is the one hook this loop leaves us — pre-seeding
    # CPPFLAGS here satisfies it.
    # CFLAGS: this compiler's default C standard is new enough to make
    # `true`/`false` reserved keywords, which breaks tests/asschk.c (an
    # unmodified upstream test helper, uses `true` as a plain int
    # variable name — predates that default). tests/ still builds as
    # part of plain `make` (unlike doc/, it isn't gated behind an
    # AM_CONDITIONAL keyed off a configure flag; --disable-tests only
    # skips *running* them), so this must fix compilation, not disable
    # a flag. Pinning the last pre-C23 GNU dialect is the standard,
    # minimal fix for old sources hitting a newer compiler's default.
    #
    # am_cv_func_iconv_works: answers gnulib's AM_ICONV self-test, which
    # compiles *and runs* a small iconv(3) program. On virt/pi4/pi5
    # ($target is aarch64, the same CPU arch as this build host) the
    # produced binary genuinely executes right here, so configure isn't
    # guessing — but the test predates a newer GCC default that turns an
    # internal ICONV_CONST mismatch in its own conftest into a hard
    # -Wincompatible-pointer-types error, unrelated to whether glibc's
    # actual iconv() works (it does — confirmed separately: pi0, where
    # $target genuinely can't execute here, takes AM_ICONV's own cross-
    # compiling fallback and answers "guessing yes" for the identical
    # glibc). Answering directly sidesteps the broken self-test instead
    # of the real question.
    #
    # PKG_CONFIG_LIBDIR/_SYSROOT_DIR: gnutls detection (configure.ac's
    # PKG_CHECK_MODULES([LIBGNUTLS], [gnutls >= 3.2])) goes through plain
    # pkg-config, not a *-config script like the other deps above, so the
    # GPGRT_CONFIG-style absolute path doesn't apply here. LIBDIR replaces
    # pkgconf's compiled-in default search path (rather than adding to
    # it, like PKG_CONFIG_PATH would) so only the target tree's own .pc
    # files are seen, never TOOL_DIR's bind-mounted host copies; SYSROOT_DIR
    # remaps gnutls.pc's own runtime-relative "prefix=/usr" onto this
    # build's real on-disk target tree — see gnutls.sh's own prepare() for
    # the fuller version of this same rationale (package/systemd.sh is
    # this project's original precedent for the mechanism).
    #
    # --disable-ntbtls: gnupg tries NTBTLS before falling back to GnuTLS
    # (see configure.ac); no target build of NTBTLS exists in this
    # project (and none is planned — GnuTLS was the deliberate choice,
    # see gnutls.sh), so skip straight to the GnuTLS probe instead of
    # relying on an implicit "ntbtls-config not found" fallback.
    am_cv_func_iconv_works=yes \
    CFLAGS=-std=gnu17 \
    CPPFLAGS=-I$INSTALL_DIR/$SYSTEM_KEY/usr/include/libusb-1.0 \
    GPGRT_CONFIG=$INSTALL_DIR/$SYSTEM_KEY/usr/bin/gpgrt-config \
    PKG_CONFIG_LIBDIR=$INSTALL_DIR/$SYSTEM_KEY/usr/lib/pkgconfig \
    PKG_CONFIG_SYSROOT_DIR=$INSTALL_DIR/$SYSTEM_KEY \
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-doc \
        --disable-keyboxd \
        --disable-tofu \
        --disable-ldap \
        --disable-wks-tools \
        --disable-gpgtar \
        --disable-photo-viewers \
        --disable-ntbtls \
        --enable-ccid-driver \
        --with-libgpg-error-prefix=$INSTALL_DIR/$SYSTEM_KEY/usr \
        --with-libgcrypt-prefix=$INSTALL_DIR/$SYSTEM_KEY/usr \
        --with-libassuan-prefix=$INSTALL_DIR/$SYSTEM_KEY/usr \
        --with-libksba-prefix=$INSTALL_DIR/$SYSTEM_KEY/usr \
        --with-npth-prefix=$INSTALL_DIR/$SYSTEM_KEY/usr
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
