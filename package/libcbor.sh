: ${package_version:=0.14.0}
: ${package_source:=https://github.com/PJK/libcbor/archive/v$package_version/libcbor-$package_version.tar.gz}
: ${package_source_hash:=sha256:a8c1516e741562cf95aa4479c64916c3d4d2623e24fdc35e414e2320e7300aae}
: ${package_description:=CBOR serialization library.}
: ${package_license:=MIT}

prepare() {
    case $package_component in
        libcbor)
            # The cross toolchain finds the sysroot's headers and libraries by itself, and
            # pkg-config is pointed at the sysroot. CMake looks for programs on the build machine,
            # and for everything else in the sysroot only. The project asks for a C++ compiler
            # without using it, and builds as C99, not as the C23 that the compiler allows.
            cmake $package_source_dir \
                ${host:+-DCMAKE_SYSTEM_NAME=Linux} \
                ${host:+-DCMAKE_SYSTEM_PROCESSOR=$target_arch} \
                ${host:+-DCMAKE_C_COMPILER=$host-gcc} \
                ${host:+-DCMAKE_CXX_COMPILER=$host-g++} \
                ${sysroot:+-DCMAKE_FIND_ROOT_PATH=$sysroot} \
                ${sysroot:+-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER} \
                ${sysroot:+-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY} \
                ${sysroot:+-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY} \
                ${sysroot:+-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY} \
                ${prefix:+-DCMAKE_INSTALL_PREFIX=$prefix} \
                -DCMAKE_INSTALL_LIBDIR=lib \
                -DCMAKE_BUILD_TYPE=Release \
                -DCMAKE_C_STANDARD=99 \
                -DBUILD_SHARED_LIBS=ON \
                -DWITH_EXAMPLES=OFF \
                -DWITH_TESTS=OFF
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        libcbor)
            cmake --build .
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        libcbor)
            DESTDIR=$package_install_dir cmake --install .
            move_to_dev_component usr/lib/cmake
            move_to_docs_component
            ;;
        dev)
            install_component
            ;;
        *)
            default_install
            ;;
    esac
}
