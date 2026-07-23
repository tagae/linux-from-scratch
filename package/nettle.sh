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
    # Compiling/linking against gmp needs nothing extra: this is a plain
    # AC_CHECK_LIB(gmp, ...)/#include <gmp.h> probe, no pkg-config or
    # *-config script involved, and target_sysroot_cc's --sysroot already
    # makes -lgmp/<gmp.h> resolve against the target tree gmp installed
    # into by depends() above (unlike the gnupg family's *-config-script
    # probes, which need an explicit absolute path because those resolve
    # via $PATH, not the sysroot — see libassuan.sh).
    #
    # --with-lib-path IS still needed, but for a different reason: RUNning
    # a just-linked-against-gmp test program, not finding gmp at
    # link time. On virt/pi4 ($target is the same CPU arch as this build
    # host), autoconf's cross_compiling check genuinely executes compiled
    # binaries right here (see gnupg.sh's own am_cv_func_iconv_works
    # comment for the identical situation) — so once nettle's own
    # AC_CHECK_LIB(gmp, __gmpn_zero_p) test succeeds and adds -lgmp to
    # LIBS, every subsequent test program nettle *runs* (its own
    # LSH_RPATH_FIX probe immediately afterwards, then the GMP_NUMB_BITS
    # AC_COMPUTE_INT check) links against gmp too — and fails to execute,
    # because our target gmp lives in $INSTALL_DIR/$PLATFORM/usr/lib, a
    # path the dynamic loader has no reason to search by default
    # (confirmed empirically: "Running simple test program failed. Trying
    # -R flags... failed" -> "cannot find value of GMP_NUMB_BITS"). Nettle
    # already has a purpose-built fix for exactly this — LSH_RPATH_FIX
    # retries with -Wl,-rpath,<dir> for each directory named in
    # --with-lib-path (see configure.ac's LSH_RPATH_INIT call) — but its
    # own default candidate list is a handful of generic system paths
    # (/usr/local/lib, /sw/lib, ...) that obviously never include our
    # target tree. Naming it explicitly here fixes the rpath retry;
    # harmless on pi0 (genuinely cross-arch), where LSH_RPATH_FIX's whole
    # mechanism is skipped (it's gated on cross_compiling = no).
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
        --with-lib-path=$INSTALL_DIR/$PLATFORM/usr/lib \
        --disable-static \
        --disable-documentation
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
