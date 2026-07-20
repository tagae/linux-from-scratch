# ncdu — an ncurses disk usage analyzer. Optional add-on package: not part
# of any bootable-* umbrella, install it on demand into a platform's target
# tree with `./lfs install ncdu` (into the systemd flavor — ncdu is
# dynamically linked against glibc, which the static-busybox flavor lacks).
#
# ncdu 1.x is C (2.x is Zig, which this project has no toolchain for). It
# links wide-char ncurses, which the base system doesn't ship, so this
# package pulls in a target build of it via depends() below — a leaf
# package declaring its own build dependency, the same require() mechanism
# the umbrella packages use.
: ${package_version:=1.22}
: ${package_source:=https://dev.yorhel.nl/download/ncdu-$package_version.tar.gz}
# Optional: verified against the downloaded archive before unpacking.
: ${package_source_sha256:=0ad6c096dc04d5120581104760c01b8f4e97d4191d6c9ef79654fa3c691a176b}

# host/prefix/install-dir come from target_build_env (applied by install());
# build= forces autoconf to treat a same-arch target (virt/pi4) as a cross
# build; target_sysroot_cc compiles/links against the target tree (its libc
# and the ncursesw installed by depends()).
: ${build:=$(cc -dumpmachine)}
target_sysroot_cc

depends() {
    # Wide-char ncurses, shared, installed into the same target tree. Its
    # own upstream defaults otherwise; knobs scoped to this require() so they
    # don't leak into ncdu's own build below.
    ( shared=yes widec=yes ada=no require ncurses )
}

prepare() {
    # NCURSES_CFLAGS/NCURSES_LIBS override ncdu's pkg-config probe for
    # ncursesw (cross pkg-config would otherwise need its own sysroot
    # plumbing). The headers live in the ncursesw/ subdir of the target
    # tree; -lncursesw resolves via the sysroot library path baked into
    # CC by target_sysroot_cc.
    NCURSES_CFLAGS="-I$INSTALL_DIR/$SYSTEM_KEY/usr/include/ncursesw" \
    NCURSES_LIBS="-lncursesw" \
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --with-ncursesw
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
