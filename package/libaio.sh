: ${package_version:=0.3.113}
: ${package_source:=https://pagure.io/libaio/archive/libaio-$package_version/libaio-$package_version.tar.gz}
: ${package_source_hash:=sha256:1c561c20670c5c09cc8437a622008c0693c6a7816c1f30332da3796953b2f454}

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
