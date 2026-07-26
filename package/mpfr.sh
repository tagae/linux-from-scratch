: ${package_version:=4.2.2}
: ${package_source:=https://ftpmirror.gnu.org/mpfr/mpfr-$package_version.tar.xz}
: ${package_source_hash:=sha256:b67ba0383ef7e8a8563734e2e889ef5ec3c3b898a01d00fa0a6869ad81c6ce01}

# build=: see gmp.sh's copy of this guard for why a target build (e.g. the
# guest-native gcc's own --with-mpfr, see package/native-toolchain.sh)
# needs it. Deliberately `gcc`, not `cc` (unlike gmp.sh/nettle.sh's own
# copy of this guard): no package here ever installs a bare "cc" (only
# "gcc" — see lib/tools.sh's relocation loop, gated on $TOOL_DIR/bin/
# $native_target-cc, which plain `make install` from gcc's own build
# never creates), so `cc -dumpmachine` silently resolves to nothing
# (command not found, swallowed by errexit's `:`-assignment exemption)
# and build= silently stays empty — confirmed empirically. `gcc` is the
# name this project's own native toolchain relocation actually provides.
# target_sysroot_cc: links the target tree's own gmp (installed there
# ahead of this by the same caller) — same trio the gnupg family already
# carries (see libassuan.sh).
: ${build:=$(gcc -dumpmachine)}
target_sysroot_cc

prepare() {
    # --with-sysroot (only meaningful once host=$target, i.e. when
    # target_sysroot_cc above actually set CC): libtool's OWN sysroot
    # mechanism, separate from the compiler's --sysroot already baked into
    # CC. Without it, the just-installed libgmp.la this links against (via
    # plain -lgmp, resolved through CC's own --sysroot at compile/link
    # time) still records its libdir as the bare, un-adjusted "/usr/lib"
    # (its own eventual runtime path, correct once booted — see gnutls.sh's
    # identical rationale) — and libtool's *own* later lookups of that
    # recorded path (e.g. by mpc.sh linking against this package's own
    # libmpfr.la, which in turn re-resolves libmpfr.la's recorded gmp
    # dependency) take it completely literally, landing on the scratch
    # container's real /usr/lib (bind-mounted from $TOOL_DIR, see docker-
    # compose.yaml) instead of the target tree — confirmed empirically via
    # mpc's own build ("libgmp.la: No such file or directory" against that
    # literal path). --with-sysroot makes libtool rewrite any such
    # recorded path through this prefix first.
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${host:+--with-sysroot=$INSTALL_DIR/$SYSTEM_KEY} \
        --disable-static \
        ${thread_safe:+--enable-thread-safe=$thread_safe} \
        --docdir=${prefix:-/usr}/share/doc/mpfr-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
