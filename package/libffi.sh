: ${package_version:=3.5.2}
: ${package_source:=https://github.com/libffi/libffi/releases/download/v$package_version/libffi-$package_version.tar.gz}
: ${package_source_hash:=sha256:f3a3082a23b37c293a4fcd1053147b371f2ff91fa7ea1b2a52e335676bac82dc}

prepare() {
    # --libdir + --disable-multi-os-directory: libffi's configure actually
    # installs its shared library via a separate "toolexeclibdir" variable,
    # not the standard $(libdir) --libdir sets — by default toolexeclibdir is
    # $(libdir) suffixed with `$CC -print-multi-os-directory` (e.g. "../lib64"
    # on this native aarch64 host), independently of where its pkgconfig file
    # lands (still plain .../lib/pkgconfig). So a pkg-config-driven consumer
    # (e.g. p11-kit's meson) links fine against -L${prefix}/lib64, but every
    # native binary here gets a single, fixed rpath of just $TOOL_DIR/usr/lib
    # (see _tools_set_rtld_ldflags in lib/tools.sh), so libffi.so.8 wouldn't
    # be found at runtime. --disable-multi-os-directory drops that suffix, so
    # toolexeclibdir collapses to plain $(libdir) — the single libdir every
    # other package here uses (see openssl.sh's own --libdir=lib).
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --libdir=$prefix/lib \
        --disable-multi-os-directory \
        --disable-static \
        ${arch:+--with-gcc-arch=$arch}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
