: ${package_version:=7.0.3}
: ${package_source:=https://github.com/gavinhoward/bc/releases/download/$package_version/bc-$package_version.tar.xz}

# Custom build system (configure.sh, not autoconf) — no --host/--build.
prepare() {
    CC='gcc -std=c99' $package_source_dir/configure \
        ${prefix:+--prefix=$prefix} \
        -O3
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
