: ${package_version:=0.3.113}
: ${package_source:=https://releases.pagure.org/libaio/libaio-$package_version.tar.gz}
: ${package_source_hash:=sha256:2c44d1c5fd0d43752287c9ae1eb9c023f04ef848ea8d4aafa46e9aedb678200b}

# Plain Makefile project, no configure script.
prepare() {
    # Skip installing the static library — we only need the shared one.
    sed -i '/install.*libaio\.a/s/^/#/' $package_source_dir/src/Makefile
}

build() {
    make -C $package_source_dir CC=gcc
}

install() {
    make -C $package_source_dir install DESTDIR=$package_install_dir CC=gcc
}
