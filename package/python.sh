: ${package_version:=3.14.7}
: ${package_source:=https://www.python.org/ftp/python/$package_version/Python-$package_version.tar.xz}
: ${package_source_hash:=sha256:3b48dac8fb59f62eaa67ac83c1eb12bda1b7a08406dd286e252c11a66be27f81}

package_source_dir=$SOURCE_DIR/Python-$package_version

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
: ${build_python:=$TOOL_DIR/usr/bin/python3}

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

    # Same patch the LFS book applies for this exact package/version: fixes
    # building and running the ssl module against OpenSSL 4.0.
    patch_source https://www.linuxfromscratch.org/patches/lfs/$lfs_version/Python-$package_version-openssl_4-1.patch \
        sha256:707a0c457192ac2f3b5b8a51481bc5ebd12db22d57c1dbe0256138ee6e070792

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
