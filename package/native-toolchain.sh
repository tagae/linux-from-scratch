# Guest-native toolchain: binutils, gcc and make built as TARGET packages —
# host=$target (not the usual host=build cross-compiler these scripts
# normally produce), so the resulting binaries RUN on $target and EMIT
# $target code, i.e. they execute inside the booted system itself, rather
# than in the build container (see SELF-HOST.md milestone M1: "target
# packages for binutils/gcc/make ... compile and run hello.c natively").
#
# Optional, like the gnupg family: not a member of any bootable-$INIT
# umbrella, installed on demand via `./lfs install native-toolchain`
# (target_build_env supplies the install scenario — host=$target,
# package_install_dir=$INSTALL_DIR/$SYSTEM_KEY, ...). package_meta=yes:
# depends() below is the whole recipe (see _install in lib/package.sh),
# same shape as bootable-systemd.sh/bootable-busybox.sh.
#
# gcc needs gmp/mpfr/mpc as HOST libraries (gcc's own "host" = $target
# here — the same build/host/target three-way split every gcc build
# already goes through, see gcc.sh's cross_target comment). gcc.sh's
# fetch() always symlinks gmp/mpfr/mpc source into the gcc tree so its own
# build can bundle them, but building those bundled copies this way (host=
# $target, build=container, a "Canadian cross") would hit the exact same
# cross_compiling=maybe ambiguity gmp.sh's own comment describes, with no
# knob to fix it from outside gcc's own submodule build. So instead they
# are built here as their own already-proven target packages first (gmp.sh
# already supports this — nettle.sh already pulls in a target gmp the same
# way) and handed to gcc via --with-gmp/--with-mpfr/--with-mpc (see
# gcc.sh), which makes gcc's own configure skip its bundled copies
# entirely and link these instead.
#
# A version is required only because the framework derives every package's
# own work/stamp paths from it (there is no source to download) — see
# bootable-systemd.sh's identical comment.
: ${package_version:=0.1.0}
package_meta=yes

depends() {
    # Kernel UAPI headers: deliberately absent from the target tree (every
    # package script that touches this says so) — the system's own glibc
    # build only ever used $TOOL_DIR/$target's copy at ITS build time,
    # never installing them into $INSTALL_DIR/$SYSTEM_KEY (glibc's own
    # install() copies only its own headers there). This coexists fine
    # with glibc's headers already in that tree: kernel headers own only
    # linux/, asm/, asm-generic/, etc. — namespaces glibc never installs
    # into. cross_arch defaults to $ARCH (linux.sh), already right for
    # this platform's own headers.
    require linux#headers

    # gmp/mpfr/mpc, host=$target — see the header comment. mpfr.sh/mpc.sh
    # carry their own build=/target_sysroot_cc guards now (mirroring
    # nettle.sh); gmp.sh already had a build= guard of its own too, BUT it
    # (like every other package's copy of this idiom) derives it from
    # `cc -dumpmachine`, and no package here ever installs a bare "cc"
    # (only "gcc" — see mpfr.sh's comment on its own copy of this guard)
    # — so gmp.sh's own fallback silently resolves to an empty build=,
    # defeating its purpose. Set it explicitly here instead of editing
    # gmp.sh itself (shared with the gnupg family, unrelated to this
    # package) — an already-set build= short-circuits gmp.sh's own `:
    # ${build:=...}` no-op.
    (
        build=$(gcc -dumpmachine)
        require gmp
    )
    require mpfr
    require mpc

    # Binutils, host=$target: no different from any other target package
    # build (see the gnupg family) — binutils itself links nothing
    # installed into the target tree, so no target_sysroot_cc is needed;
    # plain --host=$target already resolves (via bare PATH lookup) to the
    # existing $target-gcc cross-compiler (pass2, from $TOOL_DIR/bin) to
    # build it, the same compiler pass2 itself was built with. cross_target
    # defaults to $target already (binutils.sh), so host=target=target — a
    # native binutils, just cross-built. gprofng=no/werror=no mirrors
    # pass2's own choice in lib/tools.sh (gprofng needs a native perl/bison
    # setup on the *host*, irrelevant/untested here; werror=no as a general
    # new-compiler-vs-old-source safety margin).
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

    # Bare "cc": gcc's own build (host==target above, is_cross_compiler=no
    # in its own terms) already installs plain "gcc"/"g++"/"c++" itself —
    # confirmed empirically (hardlinked to the $target-prefixed names) —
    # but never "cc", the POSIX-conventional C compiler name a plain
    # ./configure/Makefile run ON the guest itself (see SELF-HOST.md Tier
    # 3) is liable to look for first. package_install_dir is ambient here
    # (ditto every require() above), already $INSTALL_DIR/$SYSTEM_KEY.
    ln -sfv gcc $package_install_dir/usr/bin/cc
}
