# GnuTLS — this project's TLS backend for gnupg's dirmngr (the daemon gpg
# shells out to for keyserver access). See package/gnupg.sh's header
# comment for why dirmngr's own configure hard-requires a TLS backend
# (NTBTLS or GnuTLS) to be built AT ALL, even for plain hkp://. GnuTLS was
# chosen over NTBTLS: it's what BLFS itself uses, and — the deciding
# reason — it can point straight at the from-scratch CA trust store this
# project already builds (make-ca + p11-kit, see package/ca-certificates.sh)
# as its own compiled-in default trust anchor, with zero new trust-store
# machinery of its own. Matches BLFS's gnutls-3.8.12 page's own version pin.
: ${package_version:=3.8.12}
: ${package_source:=https://www.gnupg.org/ftp/gcrypt/gnutls/v3.8/gnutls-$package_version.tar.xz}
: ${package_source_hash:=sha256:a7b341421bfd459acf7a374ca4af3b9e06608dcd7bd792b2bf470bea012b8e51}

# host/prefix/install-dir come from target_build_env; build= forces
# autoconf to treat a same-arch target (virt/pi4) as a cross build;
# target_sysroot_cc compiles/links against the target tree's own libc and
# the nettle/libtasn1 installed there by depends() below — same trio
# every gnupg-family script already carries (see gnupg.sh).
: ${build:=$(gcc -dumpmachine)}
target_sysroot_cc

depends() {
    # Crypto primitives (nettle+hogweed) and ASN.1/DER parsing (libtasn1,
    # for X.509 certs) — both target builds landing in the same tree this
    # configure below then finds via PKG_CONFIG_LIBDIR/_SYSROOT_DIR. No
    # knobs needed — both packages' own defaults already suit a linked-
    # shared-library consumer.
    require nettle
    require libtasn1
}

prepare() {
    # nettle/hogweed/libtasn1 are found via plain pkg-config .pc files
    # (unlike the gnupg family's *-config-script probes) — PKG_CHECK_
    # MODULES calls in gnutls's own m4/hooks.m4, confirmed by reading
    # nettle.pc.in/hogweed.pc.in/libtasn1's own generated .pc: all of
    # them, like every package here, are built with --prefix=/usr (the
    # target's own eventual runtime prefix), so their .pc files carry a
    # bare "prefix=/usr", not this build's real on-disk path.
    #
    # PKG_CONFIG_LIBDIR replaces pkgconf's compiled-in default search
    # path (rather than adding to it, like PKG_CONFIG_PATH would) — the
    # scratch container bind-mounts TOOL_DIR/usr/lib onto /usr/lib, so
    # without this, pkgconf's default /usr/lib/pkgconfig would leak the
    # build tools' own host .pc files (see package/systemd.sh for this
    # project's established rationale, same mechanism here).
    #
    # PKG_CONFIG_SYSROOT_DIR remaps each .pc file's own runtime-relative
    # "prefix=/usr" onto the target tree's actual on-disk location for
    # this build, so the "-I/usr/include"/"-L/usr/lib" pkg-config would
    # otherwise emit land in $INSTALL_DIR/$PLATFORM/usr/{include,lib}
    # instead of the container's real (wrong-architecture) /usr.
    #
    # --with-sysroot is the libtool analogue of the pkg-config vars above:
    # libtasn1 (like nettle/hogweed) is built with libtool, whose
    # generated .la file (see libtasn1.sh's own install()) always records
    # the dependency's intended FINAL runtime "libdir" (bare "/usr/lib" —
    # correct once booted, meaningless mid-build) rather than wherever
    # libtool actually found the .la file on THIS build's own disk.
    # Without telling libtool about our sysroot, its own link-time
    # dependency resolution trusts that recorded "/usr/lib" literally —
    # which, in the scratch container, is bind-mounted onto TOOL_DIR's
    # own (build-host-arch) copies, not this target tree — and silently
    # hands the linker a wrong-architecture library, confirmed
    # empirically ("file not recognized: file format not recognized"
    # against TOOL_DIR's own native libtasn1.so, installed there for
    # p11-kit's unrelated native use — see libtasn1.sh). --with-sysroot
    # is libtool's own purpose-built mechanism for exactly this (see
    # m4/libtool.m4's _LT_WITH_SYSROOT): it rewrites any dependency .la
    # file's recorded absolute paths through this prefix before using
    # them, so libtasn1 (and nettle/hogweed, in case a future collision
    # made those affected too) resolve against the actual on-disk target
    # tree instead.
    #
    # --without-p11-kit: no target build of p11-kit exists — see
    # package/p11-kit.sh, which has only ever been built as a native
    # build-host tool (for make-ca). Paired with --with-default-trust-
    # store-file below instead of the PKCS#11-URI trust store BLFS
    # itself defaults to.
    #
    # --with-included-unistring: bundle GnuTLS's own copy of libunistring
    # rather than requiring a separate target build of it. Its only
    # consumer here is IDNA (internationalized domain names), which
    # plain-ASCII keyserver hostnames don't need — see --without-idn.
    #
    # --with-default-trust-store-file: ⚠️ this is the RUNTIME absolute
    # path on the deployed/booted target ("/etc/ssl/certs/ca-
    # certificates.crt", see package/ca-certificates.sh — every target
    # tree gets this file, not just the build container), because it is
    # compiled into libgnutls as a hardcoded C string literal
    # (DEFINE_UNQUOTED DEFAULT_TRUST_STORE_FILE) read at actual runtime
    # by the booted system, NOT a DESTDIR-relative build-time path (that
    # path only ever exists inside this build, never on the target).
    # gnutls's own configure.ac only auto-probes a handful of
    # conventional paths, including this exact one, when NOT cross-
    # compiling (build=host) — for a cross build (always true here) it
    # would otherwise bake in an empty default, so this flag is required,
    # not just belt-and-suspenders.
    #
    # --disable-doc: this project's standing no-package-docs policy (see
    # e.g. libgpg-error.sh's own --disable-doc) — covers man/info/html
    # together in one flag here (gnutls's own ./configure --help), unlike
    # nettle's separate --disable-documentation.
    # --disable-tests: don't build/run gnutls's own (large) test suite.
    # --disable-tools: skip certtool/gnutls-cli/gnutls-serv/p11tool/etc —
    #   dirmngr only links libgnutls itself, none of gnutls's own client
    #   tools (same instinct as gnupg.sh disabling gpgtar/photo-viewers).
    # --disable-cxx: skip libgnutlsxx (the C++ wrapper) — dirmngr/gpg are
    #   plain C, nothing here links it.
    # --disable-libdane: skip libdane (DNSSEC/DANE cert pinning via
    #   libunbound) — no target build of libunbound exists, and DANE is
    #   unrelated to a keyserver TLS connection; would otherwise just
    #   silently auto-disable (libunbound absent), but disabling
    #   explicitly avoids relying on that fallback.
    # --without-idn: no IDNA/libidn2 support — plain-ASCII keyserver
    #   hostnames don't need it (see --with-included-unistring above).
    # --disable-static: matches every other target package here (gmp.sh,
    #   libtasn1.sh, ...); also already gnutls's own upstream default.
    #
    # zlib compression support is deliberately left at its default
    # (auto-detected via pkg-config): a target zlib is already built
    # ahead of gnutls in the install order (see gnupg.sh's comment), so
    # this costs nothing extra and matches BLFS's own default.
    PKG_CONFIG_LIBDIR=$INSTALL_DIR/$PLATFORM/usr/lib/pkgconfig \
    PKG_CONFIG_SYSROOT_DIR=$INSTALL_DIR/$PLATFORM \
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --with-sysroot=$INSTALL_DIR/$PLATFORM \
        --without-p11-kit \
        --with-included-unistring \
        --with-default-trust-store-file=/etc/ssl/certs/ca-certificates.crt \
        --disable-doc \
        --disable-tests \
        --disable-tools \
        --disable-cxx \
        --disable-libdane \
        --without-idn \
        --disable-static
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
