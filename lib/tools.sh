tools() {
    case "${1:-help}" in
        bootstrap) tools_bootstrap ;;
        build)     tools_build ;;
        help)
            echo "Usage: $(basename "$0") tools <bootstrap|build>"
            if [ $# -eq 1 ]; then exit 0; else exit 1; fi
            ;;
        *) bail "Unknown command '$1'" ;;
    esac
}

tools_bootstrap() {
    # --- Cross toolchain (throwaway) ------------------

    # Binutils pass 1: cross-assembler/linker.
    package_variant=pass1 \
        prefix=$TOOL_DIR/cross sysroot=$TOOL_DIR package_install_dir=/ \
        gprofng=no install binutils

    # GCC pass 1: minimal C cross-compiler to build glibc.
    package_variant=pass1 \
        prefix=$TOOL_DIR/cross sysroot=$TOOL_DIR package_install_dir=/ \
        newlib=yes headers=no shared=no fixincludes=no \
        threads=no libatomic=no libgomp=no libquadmath=no libssp=no \
        libvtv=no libstdcxx=no \
        install gcc

    # Linux kernel headers to build glibc.
    package_install_dir=$TOOL_DIR install linux#headers

    # GNU C library: the glibc that all toolchain binaries will link against.
    prefix=/usr headers=$TOOL_DIR/usr/include \
        package_install_dir=$TOOL_DIR install glibc

    # Verify the cross-compiler references our glibc dynamic linker.
    echo 'int main(){}' | $TOOL_DIR/cross/bin/$target-gcc --sysroot=$TOOL_DIR -xc -
    readelf -l a.out | grep -q ld-linux || bail "Cross-compiler does not use glibc ld"
    rm -f a.out

    # GCC pass1 (--with-newlib) generates a minimal limits.h that defines
    # MB_LEN_MAX=1 and lacks #include_next, so glibc's PATH_MAX, _POSIX_ARG_MAX,
    # etc. are unreachable for cross-compiled packages.  Chain to glibc's limits.h:
    # define _GCC_LIMITS_H_ first so glibc's own #include_next guard does not loop.
#     _gcc_lib=$(dirname $($TOOL_DIR/cross/bin/$target-gcc -print-libgcc-file-name))
#     sed -i 's/^#define MB_LEN_MAX 1$/#define MB_LEN_MAX 16/' \
#         $_gcc_lib/include/limits.h
#     sed -i "/^#endif.*_LIMITS_H___/{i\\#define _GCC_LIMITS_H_
# i\\#include_next <limits.h>
# }" $_gcc_lib/include/limits.h

    # C++ standard library (cross-compiled into TOOL_DIR/usr).
    package_install_dir=$TOOL_DIR install gcc#libstdc++

    # --- Temporary tools (glibc-linked, relocatable) ---------------

    (
        host=$target
        prefix=$TOOL_DIR/cross
        nls=no

        install m4
        install ncurses#tic
        install ncurses
        install bash
        install_program=hostname no_install_program=kill,uptime install coreutils
        install diffutils
        install file#native
        install file
        localstatedir=$TOOL_DIR/var/lib/locate install findutils
        install gawk
        install grep
        install gzip
        install make
        install patch
        install sed
        install tar
        install xz
        install util-linux # Provides getopt, needed by ./lfs to parse args in phase 2.
    )

    exit 0

    # Binutils pass 2: native (glibc-linked) linker/assembler.
    package_variant=pass2 \
        host=$target prefix=/usr sysroot=$TOOL_DIR \
        package_install_dir=$TOOL_DIR gprofng=no install binutils

    # GCC pass 2: native compiler for the target (glibc-linked, Canadian cross).
    host=$target \
        prefix=/usr sysroot=$TOOL_DIR \
        package_install_dir=$TOOL_DIR \
        libsanitizer=no \
        install gcc
}

tools_build() {
    # Runs in the scratch container (or bare host) using only the toolchain.
    # Phase 2: native builds that dogfood the bootstrapped toolchain.
    host=$target prefix=/usr package_install_dir=$TOOL_DIR install coreutils
}
