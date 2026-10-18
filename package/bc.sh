: ${package_version:=7.0.3}
: ${package_source:=https://github.com/gavinhoward/bc/releases/download/$package_version/bc-$package_version.tar.xz}
: ${package_source_hash:=sha256:91eb74caed0ee6655b669711a4f350c25579778694df248e28363318e03c7fc4}
: ${package_description:=Arbitrary-precision calculators bc and dc.}
: ${package_license:=BSD-2-Clause AND MIT}

prepare() {
    CC="${CC:-${host:+$host-}gcc} -std=c99" $package_source_dir/configure \
        ${prefix:+--prefix=$prefix} \
        -O3
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
