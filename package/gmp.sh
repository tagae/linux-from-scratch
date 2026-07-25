: ${package_version:=6.3.0}
: ${package_source:=https://ftpmirror.gnu.org/gmp/gmp-$package_version.tar.xz}
: ${package_source_hash:=sha256:a3c2b80201b89e68616f4ad30bc66aee4927c3ce50e33929ca819d5c43538898}

# build=: only matters for a target build (e.g. nettle's depends() pulling
# this in for the target) — on virt/pi4, $target is the same CPU arch as
# this build host, so without an explicit, textually-different --build,
# autoconf's cross_compiling detection goes to "maybe" and some configure
# checks try to actually compile-and-run a test program against the wrong
# sysroot instead of taking their safe cross-compiling fallback. No-op for
# the existing native (tools-phase) use, which already runs with host=build.
: ${build:=$(gcc -dumpmachine)}

prepare() {
    # CFLAGS=-std=gnu17: GMP doesn't use plain AC_PROG_CC — it has its own
    # hand-tuned compiler/flags selection (GMP_PROG_CC_WORKS, run against
    # a "gcc cc" candidate list, optionally $host_alias-prefixed when
    # cross-compiling), which puts every candidate through a battery of
    # conftests, including one literally named "long long reliability
    # test 1": a K&R-era program that forward-declares `void g(){}` (old
    # style empty parens, meaning "unspecified arguments") and then calls
    # it with six arguments — legal pre-C23, but a hard "too many
    # arguments to function 'g'" error once empty parens mean "takes no
    # arguments" instead. This project's GCC defaults to a C standard new
    # enough to make that switch, so *every* candidate GMP tries (both
    # $target-gcc and plain build-host gcc — confirmed via config.log,
    # this is not a missing- or wrong-compiler problem) fails this same
    # probe, and configure aborts with "could not find a working
    # compiler". GMP's own probing loop honors a user-supplied $CFLAGS
    # ahead of its internal per-compiler defaults ("Any user CFLAGS, even
    # an empty string, takes precedence" — configure.ac's own comment),
    # so pinning the last pre-C23 GNU dialect here sidesteps the broken
    # conftest instead of the real question, the same fix and rationale
    # as gnupg.sh's own identical-cause CFLAGS=-std=gnu17.
    #
    # CC_FOR_BUILD=gcc: separate from the above — a cross build (host !=
    # build, the only way this script is used, see build= above) also
    # needs GMP to compile a handful of table-generator programs that
    # must run on the *build* machine, using a build-machine-native
    # compiler distinct from $CC (the target cross-compiler). Left
    # unset, configure's own CC_FOR_BUILD detection falls back to a
    # similar candidate probe; setting it explicitly skips straight to a
    # trivial compile-and-run check instead (see configure's own
    # CC_FOR_BUILD branch). Plain "gcc" is always this project's build-
    # host-native compiler regardless of host architecture (see lib/
    # tools.sh's native_target — the same bare name every other native
    # invocation in this project relies on).
    CFLAGS=-std=gnu17 \
    CC_FOR_BUILD=gcc \
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${cxx:+--enable-cxx=$cxx} \
        --disable-static \
        --docdir=/usr/share/doc/gmp-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
