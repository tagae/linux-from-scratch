# Install order for the whole optional gnupg family (see GNUPG-YUBIKEY.md
# section 1) — nothing enforces this automatically, since these are all
# invoked ad hoc via `./lfs install <pkg>` rather than from a dependency-
# ordered build phase like build_system():
#
#   zlib -> libgpg-error -> npth -> libassuan -> libksba -> libgcrypt ->
#   libusb -> gnupg -> pinentry
#
# Keeps gpg, gpg-agent and scdaemon; keyboxd/tofu/ldap/dirmngr/wks-tools/
# gpgtar/photo-viewers/doc are all out of scope for a minimal embedded
# build (keyboxd avoids sqlite, doc avoids texinfo, dirmngr avoids a
# network daemon this project doesn't otherwise carry). --enable-ccid-
# driver lets scdaemon talk to a YubiKey directly over USB via libusb, no
# pcscd/libccid stack needed.
: ${package_version:=2.4.5}
: ${package_source:=https://gnupg.org/ftp/gcrypt/gnupg/gnupg-$package_version.tar.bz2}
: ${package_source_sha256:=f68f7d75d06cb1635c336d34d844af97436c3f64ea14bcb7c869782f96f44277}

# Links against libgpg-error/libgcrypt/libassuan/libksba/npth, all already
# installed into $INSTALL_DIR/$PLATFORM — see libassuan.sh for why
# target_sysroot_cc and explicit --with-*-prefix flags are both needed
# (gnupg's own configure probes each dependency's own *-config/pkg-config
# script, which would otherwise happily answer with a host or toolchain
# path instead — see config.log for which one, if a wrong path ever leaks).
: ${build:=$(cc -dumpmachine)}
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
    am_cv_func_iconv_works=yes \
    CFLAGS=-std=gnu17 \
    CPPFLAGS=-I$INSTALL_DIR/$PLATFORM/usr/include/libusb-1.0 \
    GPGRT_CONFIG=$INSTALL_DIR/$PLATFORM/usr/bin/gpgrt-config \
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-doc \
        --disable-keyboxd \
        --disable-tofu \
        --disable-ldap \
        --disable-dirmngr \
        --disable-wks-tools \
        --disable-gpgtar \
        --disable-photo-viewers \
        --enable-ccid-driver \
        --with-libgpg-error-prefix=$INSTALL_DIR/$PLATFORM/usr \
        --with-libgcrypt-prefix=$INSTALL_DIR/$PLATFORM/usr \
        --with-libassuan-prefix=$INSTALL_DIR/$PLATFORM/usr \
        --with-libksba-prefix=$INSTALL_DIR/$PLATFORM/usr \
        --with-npth-prefix=$INSTALL_DIR/$PLATFORM/usr
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
