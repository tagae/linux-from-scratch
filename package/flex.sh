: ${package_version:=2.6.4}
: ${package_source:=https://github.com/westes/flex/releases/download/v$package_version/flex-$package_version.tar.gz}
: ${package_source_hash:=sha256:e87aae032bf07c26f85ac0ed3250998c37621d95f8bd748b31f15b33c45ee995}

# build=: see m4.sh's copy of this guard.
: ${build:=$(gcc -dumpmachine)}

prepare() {
    # ac_cv_func_{malloc,realloc}_0_nonnull: gnulib's AC_FUNC_MALLOC/
    # AC_FUNC_REALLOC can't execute a test program while cross-compiling
    # (cross_compiling=yes, now correctly detected thanks to build= above)
    # and conservatively assume malloc(0)/realloc(p,0) might return NULL,
    # substituting a wrapping rpl_malloc/rpl_realloc that config.h then
    # #defines malloc/realloc to — but flex's own sources never declare
    # those replacement symbols (it doesn't use gnulib's malloc/realloc
    # module, only the Autoconf macro), so the #define left every genuine
    # malloc()/realloc() call in scan.c an implicit, wrongly-typed
    # rpl_malloc()/rpl_realloc() call instead (confirmed empirically —
    # "implicit declaration of function 'rpl_malloc'"). Every target this
    # project builds for is glibc, whose malloc(0)/realloc(p,0) are known
    # to always return a valid non-NULL pointer, so pre-answering "yes"
    # here is simply what the test would find anyway if it could run
    # natively — harmless on the existing native (tools-phase) build too.
    # CFLAGS/CFLAGS_FOR_BUILD=-std=gnu17: when cross-compiling, flex's own
    # "stage1flex" (a helper built with CC_FOR_BUILD — the container's bare
    # native gcc — used to bootstrap-generate scan.c from scan.l, since the
    # cross-compiled "flex" binary can't run on the build host) ALWAYS
    # bundles gnulib's ../lib/malloc.c and ../lib/realloc.c into its
    # sources regardless of the AC_FUNC_MALLOC result above (confirmed via
    # the generated Makefile: stage1flex's cross-compiling branch appends
    # them unconditionally). Their old K&R-style declaration (`void *malloc
    # ();`, empty parens meaning "unspecified arguments") is legal pre-C23
    # but a hard "too many arguments" error once empty parens mean "takes
    # no arguments" instead — the same new-GCC-vs-old-source break as
    # gmp.sh's own identical-cause CFLAGS=-std=gnu17. Pinned for
    # both variables (CFLAGS for the main cross-target build, CFLAGS_FOR_
    # BUILD for stage1) since either one alone still leaves the other half
    # compiled with GCC 16's newer default standard.
    ac_cv_func_malloc_0_nonnull=yes \
    ac_cv_func_realloc_0_nonnull=yes \
    CFLAGS=-std=gnu17 \
    CFLAGS_FOR_BUILD=-std=gnu17 \
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
