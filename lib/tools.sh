tools() {
    case "${1:-help}" in
        bootstrap)
            tools_bootstrap
            ;;
        build)
            tools_build
            ;;
        help)
            echo "Usage: $(basename "$0") tools <COMMAND>"
            echo ""
            echo "Commands:"
            echo "  bootstrap        Bootstrap the cross-compilation toolchain"
            echo "  build            Build cross-compilation toolchain"
            echo ""
            if [ $# -eq 1 ]; then exit 0; else exit 1; fi
            ;;
        *)
            bail "Unknown command '$1'"
            ;;
    esac
}

tools_bootstrap() {
    # Target the tools directory by default.
    package_install_dir=$TOOL_DIR

    prefix=$TOOL_DIR sysroot=$INSTALL_DIR package_install_dir=/ gprofng=no install binutils

    # GCC pass 1: minimal compiler for building glibc headers.
    package_variant=pass1 \
        prefix=$TOOL_DIR sysroot=$TOOL_DIR package_install_dir=/ \
        newlib=yes headers=no shared=no \
        threads=no libatomic=no libgomp=no libquadmath=no libssp=no libvtv=no libstdcxx=no \
        install gcc

    # Linux kernel headers (for glibc to reference).
    install linux#headers

    # GNU C library.
    headers=$TOOL_DIR/usr/include shared=yes install glibc

    # Sanity check: verify cross-compiler produces correct dynamic linker reference.
    # --sysroot=$TOOL_DIR: works whether gcc pass1 or the final gcc is in $TOOL_DIR/bin.
    # -fno-link-libatomic: suppresses -latomic_asneeded (a GCC 16 spec addition)
    #   so the check doesn't fail when libatomic hasn't been installed yet.
    echo 'int main(){}' | $TOOL_DIR/bin/$target-gcc --sysroot=$TOOL_DIR -fno-link-libatomic -xc -
    readelf -l a.out > a.txt
    grep ld-linux a.txt
    rm -f a.out a.txt

    # C++ standard library for the target.
    install gcc#libstdc++

    # GCC final: full cross-compiler, sysroot points to final install dir
    # so that packages built in the system phase link against the final glibc.
    # build_sysroot=$TOOL_DIR directs GCC's own build (fixincludes, libgcc) to
    # the tools sysroot where glibc already lives.
    prefix=$TOOL_DIR sysroot=$INSTALL_DIR build_sysroot=$TOOL_DIR package_install_dir=/ install gcc
}

tools_build() {
    package_install_dir=$TOOL_DIR

    # Coreutils for the toolchain.
    install coreutils
}
