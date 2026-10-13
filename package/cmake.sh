: ${package_version:=4.4.4}
: ${package_source:=https://github.com/Kitware/CMake/releases/download/v$package_version/cmake-$package_version.tar.gz}
: ${package_source_hash:=sha256:bd24c30d80a7744ae84b845ff080cc8453b06c622ef01066564108e9cefc44cf}
: ${package_description:=Cross-platform build system generator.}
: ${package_license:=BSD-3-Clause}

prepare() {
    # It bootstraps itself with the compilers at hand, and with its own copies of the libraries it
    # needs rather than the build machine's. Its network features (OpenSSL), its curses interface
    # and its tests are left out.
    $package_source_dir/bootstrap \
        ${prefix:+--prefix=$prefix} \
        --parallel=$(nproc) \
        -- \
        -DCMAKE_USE_OPENSSL=OFF \
        -DBUILD_CursesDialog=OFF \
        -DBUILD_TESTING=OFF
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
