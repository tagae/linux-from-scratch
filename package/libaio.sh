: ${package_version:=0.3.113}
: ${package_source:=https://pagure.io/libaio/archive/libaio-$package_version/libaio-$package_version.tar.gz}

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
