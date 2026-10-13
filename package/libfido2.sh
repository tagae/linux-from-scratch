: ${package_version:=1.17.0}
: ${package_source:=https://developers.yubico.com/libfido2/Releases/libfido2-$package_version.tar.gz}
: ${package_source_hash:=sha256:c1012c8871d71b65872fd5ff1a9d6b0838a55683a03e85ba97479ce57129c736}
: ${package_description:=Library and tools for FIDO2 security keys.}
: ${package_license:=BSD-2-Clause AND ISC AND BSD-3-Clause}

prepare() {
    case $package_component in
        libfido2)
            # See libcbor for the cross-compilation settings. The library finds libcbor, libcrypto,
            # zlib and libudev through pkg-config. Keys are reached through hidraw only: no NFC,
            # and no udev rules, as root is the only user.
            cmake $package_source_dir \
                ${host:+-DCMAKE_SYSTEM_NAME=Linux} \
                ${host:+-DCMAKE_SYSTEM_PROCESSOR=$target_arch} \
                ${host:+-DCMAKE_C_COMPILER=$host-gcc} \
                ${sysroot:+-DCMAKE_FIND_ROOT_PATH=$sysroot} \
                ${sysroot:+-DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER} \
                ${sysroot:+-DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY} \
                ${sysroot:+-DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY} \
                ${sysroot:+-DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY} \
                ${prefix:+-DCMAKE_INSTALL_PREFIX=$prefix} \
                -DCMAKE_INSTALL_LIBDIR=lib \
                -DCMAKE_BUILD_TYPE=Release \
                -DBUILD_SHARED_LIBS=ON \
                -DBUILD_STATIC_LIBS=OFF \
                -DBUILD_TOOLS=ON \
                -DBUILD_TESTS=OFF \
                -DBUILD_EXAMPLES=OFF \
                -DBUILD_MANPAGES=OFF \
                -DNFC_LINUX=OFF
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        libfido2)
            cmake --build .
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        libfido2)
            DESTDIR=$package_install_dir cmake --install .
            move_to_dev_component
            move_to_docs_component
            ;;
        *)
            default_install
            ;;
    esac
}
