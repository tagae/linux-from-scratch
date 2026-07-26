: ${package_version:=3.14.6}
: ${package_source:=https://www.python.org/ftp/python/$package_version/Python-$package_version.tar.xz}
: ${package_source_hash:=sha256:143b1dddefaec3bd2e21e3b839b34a2b7fb9842272883c576420d605e9f30c63}

package_source_dir=$SOURCE_DIR/Python-$package_version

# build=: see m4.sh's copy of this guard (the target build that ships this
# tool to the guest as an archive tarball).
# build_python: the native python3 CPython's own cross-build process needs
# to run at BUILD time (freezing importlib, running Parser/pgen, deriving
# platform constants it can't cross-derive by static analysis alone) —
# must be the SAME version as the one being built (confirmed by upstream:
# a mismatched build/host Python version breaks the frozen-modules step),
# which is exactly what $TOOL_DIR's own tools-phase python3 is (built by
# build_tools() from this same python.sh, same package_version). Guarded
# on host (${host:+...} below): a no-op wherever host stays unset (every
# existing native caller, including build_tools()'s own `install python`),
# since --with-build-python only makes sense once actually cross-building.
: ${build:=$(gcc -dumpmachine)}
: ${build_python:=$TOOL_DIR/usr/bin/python3}
# target_sysroot_cc: Python links target libraries beyond plain libc
# (zlib, liblzma, ...) that only exist in the target tree ($INSTALL_DIR/
# $SYSTEM_KEY — installed there by their own package builds), not in
# $target-gcc's own default sysroot ($TOOL_DIR/$target, which has only the
# per-target glibc — confirmed empirically: "zlib.h: No such file or
# directory", "lzma.h: No such file or directory" without this). Self-
# neutralizing (see lib/package.sh) wherever host isn't $target.
target_sysroot_cc

# PKG_CONFIG_LIBDIR/_SYSROOT_DIR: Python's configure probes optional
# features (libuuid for the _uuid module, among others) via pkg-config.
# Left alone, pkg-config falls back to its compiled-in default search path
# (this container's own real /usr/lib/pkgconfig, i.e. $TOOL_DIR's — see the
# cross pkg-config LIBDIR gotcha, same class of bug as PKG_CONFIG_LIBDIR
# elsewhere in this project) instead of the TARGET tree's .pc files
# ($INSTALL_DIR/$SYSTEM_KEY's own uuid.pc, installed there by util-linux).
# _SYSROOT_DIR additionally rewrites each .pc file's own recorded absolute
# paths (e.g. uuid.pc's "Cflags: -I${includedir}/uuid", literally "/usr/
# include/uuid" — a path that doesn't exist standalone in this container)
# through the target sysroot, so the -I flag pkg-config reports actually
# resolves. Guarded on host: a no-op wherever host stays unset (every
# existing native caller).
if [ "${host:-}" = "$target" ]; then
    export PKG_CONFIG_LIBDIR=$INSTALL_DIR/$SYSTEM_KEY/usr/lib/pkgconfig
    export PKG_CONFIG_SYSROOT_DIR=$INSTALL_DIR/$SYSTEM_KEY
fi

prepare() {
    : ${shared:=yes}
    # PGO (--enable-optimizations) RUNS the freshly-built interpreter to
    # collect profile data — impossible for a cross/target build, where the
    # target binary can't execute on the build host (fails at the
    # profile-run-stamp step with "Error 127"). Default it OFF when
    # cross-compiling (host set by target_build_env) and ON for a native
    # build (host unset — tools phase / guest phase), so a bare
    # `./lfs install python` for a target works without the caller needing
    # to remember the knob.
    : ${optimizations:=$([ -n "${host:-}" ] && echo no || echo yes)}
    : ${static_libpython:=no}

    # Same patch the LFS book applies for this exact package/version — the
    # OpenSSL 4.0 part fixes what --with-openssl=/nonexistent used to just
    # sidestep (Python 3.14's _ssl.c referenced TLSv1_method, which OpenSSL
    # 4.0 dropped); it also carries a few unrelated upstream CVE fixes
    # bundled into the same "consolidated_fixes" patch.
    patch_source https://www.linuxfromscratch.org/patches/lfs/development/Python-$package_version-consolidated_fixes-1.patch \
        sha256:2b10cd96a07e8c45de3ac5d5f4c7e24c10df720c529fd2de3ffec809e559d311

    # ac_cv_buggy_getaddrinfo: cross-compiling can't run Python's own
    # getaddrinfo(3) behavior probe (needs to compile-AND-run a test
    # program), and configure's own cross-compiling fallback conservatively
    # assumes "yes" (see the surrounding cases in configure — it maps a
    # cross build straight to "buggy" unless told otherwise) and then hard-
    # errors demanding either a working getaddrinfo() or --disable-ipv6.
    # glibc's getaddrinfo is not buggy on any target this project builds
    # for, so pre-answering "no" is what the test would find anyway if it
    # could run natively (same idiom as flex.sh's ac_cv_func_malloc_0_
    # nonnull override) — harmless on the existing native build too.
    #
    # ac_cv_file__dev_ptmx/_dev_ptc: same cross-compiling story as
    # ac_cv_buggy_getaddrinfo above — configure can't stat() the BUILD
    # host's /dev while cross-compiling (it needs the TARGET's, which
    # doesn't exist yet) and hard-errors demanding these in a CONFIG_SITE
    # file instead. Every target this project builds is Linux, which always
    # has /dev/ptmx (the Unix98 pty multiplexor) and never /dev/ptc (an
    # AIX/BSD-only device) — env vars serve exactly like CONFIG_SITE here.
    #
    # Cross-compiling Python requires a native Python build for host utilities.
    ac_cv_buggy_getaddrinfo=no \
    ac_cv_file__dev_ptmx=yes \
    ac_cv_file__dev_ptc=no \
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${sysroot:+--with-sysroot=$sysroot} \
        ${host:+--with-build-python=$build_python} \
        ${shared:+--enable-shared=$shared} \
        ${system_expat:+--with-system-expat} \
        ${static_libpython:+--with-static-libpython=$static_libpython} \
        ${optimizations:+--enable-optimizations=$optimizations}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
