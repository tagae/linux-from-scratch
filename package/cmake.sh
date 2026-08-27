# CMake — build-host-only tool: fish (>= 3.0) builds exclusively with
# CMake, which nothing else in the toolchain provides. Never part of any
# target tree — fish.sh's depends() installs it under the tools scenario
# (package_install_dir=$TOOL_DIR, package_merge_dir cleared), the same
# shape lib/tools.sh's own members use. 3.31.x deliberately (the last 3.x
# line, not 4.x): CMake 4 removed compatibility with pre-3.5
# cmake_minimum_required, which older projects' build files still carry.
: ${package_version:=3.31.12}
: ${package_source:=https://github.com/Kitware/CMake/releases/download/v$package_version/cmake-$package_version.tar.gz}
# Cross-checked against Kitware's published cmake-3.31.12-SHA-256.txt.
: ${package_source_hash:=sha256:5f3fd5a54dfa65602bdbed64f981a72673cc19f2d304cc2955cf0dfa0cfd8272}

prepare() {
    # CMake bootstraps itself with a plain shell script and a C++17
    # compiler — no pre-existing cmake needed. Bare gcc/g++ (NOT cc: the
    # scratch container's bare-name symlinks only cover names gcc itself
    # installs, and there is no *-cc driver to link a bare cc to) resolve
    # to the native toolchain there, and to the system compiler on a
    # booted guest — NOT any cross CC/CXX the requiring package may have
    # exported: cmake must run on the build host, which is why fish.sh's
    # depends() unsets those before require'ing this.
    # OpenSSL off: cmake's own network features (file(DOWNLOAD) etc.) are
    # unused here — every source arrives via the framework's own
    # hash-verified fetch.
    CC=gcc CXX=g++ $package_source_dir/bootstrap \
        --prefix=$prefix \
        --parallel=$(nproc) \
        -- -DCMAKE_USE_OPENSSL=OFF
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
