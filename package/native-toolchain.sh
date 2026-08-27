# Native toolchain: `binutils`, `gcc` and `make` built as TARGET packages, with host=$target (not
# the usual host=build cross-compiler), so the resulting binaries RUN on $target and EMIT $target
# code.
#
# A version is required only because the framework derives every package's
# own work/stamp paths from it (there is no source to download).
: ${package_version:=0.1.0}

package_meta=yes

depends() {
    # Kernel UAPI headers.
    require linux#headers

    (
        build=$(gcc -dumpmachine)
        require gmp
    )
    require mpfr
    require mpc

    (
        build=$(gcc -dumpmachine)
        gprofng=no werror=no \
        require binutils
    )

    # gcc, host=$target: same shape as binutils above, but gcc needs
    # headers/libs beyond plain libc (kernel headers + gmp/mpfr/mpc, all
    # installed above into $INSTALL_DIR/$SYSTEM_KEY — NOT $TOOL_DIR/
    # $target, which is what pass2's own default --sysroot points at
    # instead, and has none of those). Two different sysroot knobs solve
    # two different problems here (see gcc.sh):
    #   - build_sysroot (--with-build-sysroot) only affects how THIS gcc's
    #     own host-side sources (cc1, cc1plus, the driver, libgcc, ...) get
    #     compiled/linked during THIS build — pointed at $INSTALL_DIR/
    #     $SYSTEM_KEY so they see the kernel headers/gmp/mpfr/mpc just
    #     installed there, instead of pass2's own unrelated $TOOL_DIR/
    #     $target sysroot.
    #   - sysroot (--with-sysroot) is the DEFAULT baked into the PRODUCED
    #     compiler itself, consulted whenever it's later invoked with no
    #     explicit --sysroot — deliberately left UNSET here: this compiler
    #     runs natively ON $target, where plain "/" (an unset sysroot's
    #     default) already IS the real root at that point, exactly like
    #     any ordinary native compiler on a real machine.
    # host==target here makes gcc's own configure treat this as a NATIVE
    # build (is_cross_compiler=no, in its own terms) even though it's
    # actually cross-built (build=container) — the standard "Canadian
    # cross" shape --with-build-sysroot exists for.
    # libatomic/libgomp/libquadmath/libsanitizer/libssp/libvtv=no and
    # fixincludes=no mirror pass2's own choice in lib/tools.sh (this
    # project's target systems have no use for OpenMP/quadmath/sanitizer
    # runtimes, and fixincludes rewrites system headers that don't need it
    # here); shared/threads/libstdcxx=yes likewise, for a full C/C++
    # compiler matching pass2's own capabilities.
    #
    # nls=no: matches bootstrap_tools()/build_tools()'s own project-wide
    # choice (no translation catalogs) — needed here for a real, non-
    # cosmetic reason too, not just consistency: libstdc++-v3's own
    # in-tree subdirectory build (part of the combined `make` above)
    # unconditionally tries to generate its own po/*.mo translation
    # catalogs via msgfmt, which shells out to glibc's iconv() to convert
    # each .po file's charset (e.g. ISO-8859-1) to UTF-8 — and fails
    # ("relies on iconv(). This version was built without iconv()"),
    # because no glibc built anywhere in this project (neither $TOOL_DIR's
    # own native copy nor any target tree's) installs gconv conversion
    # modules at all ($TOOL_DIR/usr/lib/gconv, the path lib/tools.sh's own
    # GCONV_PATH convention points at for the identical gettext/bison
    # problem in build_tools(), doesn't exist — confirmed empirically;
    # exporting it here changes nothing, so it's not the fix, unlike
    # there). --enable-nls=no propagates down into every GCC subdirectory
    # configure, including libstdc++-v3's own (confirmed empirically: its
    # own po/Makefile gates the whole catalog-generation recipe behind
    # `all-local-$(USE_NLS)`, an empty no-op target when USE_NLS=no),
    # skipping the whole msgfmt step instead of working around its broken
    # iconv.
    (
        build=$(gcc -dumpmachine)
        glibc_version=$(version glibc) languages=c,c++ \
        shared=yes threads=yes libstdcxx=yes \
        fixincludes=no nls=no \
        libatomic=no libgomp=no libquadmath=no libsanitizer=no libssp=no libvtv=no \
        build_sysroot=$INSTALL_DIR/$SYSTEM_KEY \
        gmp=$INSTALL_DIR/$SYSTEM_KEY/usr mpfr=$INSTALL_DIR/$SYSTEM_KEY/usr mpc=$INSTALL_DIR/$SYSTEM_KEY/usr \
        require gcc
    )

    # make: plain autoconf, host=$target — nothing it links comes from the
    # target tree, so (like binutils above) no target_sysroot_cc is needed.
    (
        build=$(gcc -dumpmachine)
        require make
    )

    # Bare "cc" (and the usr/lib64->usr/lib relocation for gcc's own
    # libstdc++/libgcc_s) used to be created HERE — but this depends()
    # context runs under the inversion (see lib/package.sh's _install):
    # package_install_dir is deliberately UNSET while depends() runs (only
    # restored for the umbrella's own payload, which native-toolchain.sh
    # has none of, being package_meta=yes), so referencing it directly here
    # crashed. Both fixups now live in gcc.sh's own install() step instead,
    # guarded on the same host==target condition — that way they stage->
    # archive->merge like the rest of the package (see gcc.sh).
}
