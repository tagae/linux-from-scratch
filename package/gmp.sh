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
: ${build:=$(cc -dumpmachine)}

prepare() {
    # CC_FOR_BUILD: only exercised so far by a target (cross) build (see
    # build= above) — GMP needs a *build*-machine-native compiler of its
    # own, separate from $CC (the target cross-compiler), to compile a
    # handful of table-generator programs it runs during its own build.
    # Left unset, GMP's configure (GMP_PROG_CC_FOR_BUILD) probes a
    # candidate list ("$host_alias-gcc", "gcc", "$host_alias-cc", "cc")
    # via its own "long long reliability test" conftest — a K&R-era
    # program that calls `g(i, ...six args...)` against a `void g(){}`
    # forward declaration, relying on empty parens meaning "unspecified
    # arguments" (true pre-C23). This project's GCC defaults to a new
    # enough C standard that empty parens now mean "no arguments", so
    # *every* candidate in GMP's list fails that probe with a hard
    # "too many arguments to function 'g'" compile error, and configure
    # aborts with "could not find a working compiler" — even though the
    # underlying compilers (both $target-gcc and plain build-host gcc)
    # are completely fine. Explicitly setting CC_FOR_BUILD skips that
    # whole broken candidate loop for a trivial compile-and-run check
    # instead (see configure's own CC_FOR_BUILD branch), sidestepping
    # the broken conftest rather than the real question. Plain "gcc" is
    # always this project's build-host-native compiler regardless of
    # host architecture (see lib/tools.sh's native_target — the same
    # bare name every other native invocation in this project relies
    # on), so it's the correct choice unconditionally here, not just for
    # today's build host.
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
