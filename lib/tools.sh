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
    # --- Cross Toolchain Pass 1 (throwaway) ------------------

    # Cross-assembler and linker.
    package_variant=pass1 package_install_dir=/ \
        prefix=$TOOL_DIR sysroot=$TOOL_DIR \
        nls=no gprofng=no werror=no new_dtags=yes default_hash_style=gnu \
        install binutils

    # Minimal C cross-compiler to build glibc.
    package_variant=pass1 package_install_dir=/ \
        prefix=$TOOL_DIR sysroot=$TOOL_DIR build_sysroot=$TOOL_DIR \
        glibc_version=$(version glibc) \
        newlib=yes headers=no \
        default_pie=yes default_ssp=yes \
        fixincludes=no \
        nls=no shared=no multilib=no threads=no \
        libatomic=no libgomp=no libquadmath=no libssp=no libvtv=no libstdcxx=no\
        languages=c,c++ \
        install gcc

    exit 0

    # Linux kernel headers to build glibc.
    package_install_dir=$TOOL_DIR install linux#headers

    # GNU C library: the glibc that all toolchain binaries will link against.
    prefix=/usr headers=$TOOL_DIR/usr/include \
        package_install_dir=$TOOL_DIR install glibc

    # Verify the cross-compiler references our glibc dynamic linker.
    echo 'int main(){}' | $TOOL_DIR/bin/$target-gcc --sysroot=$TOOL_DIR -xc -
    readelf -l a.out | grep -q ld-linux || bail "Cross-compiler does not use glibc ld"
    rm -f a.out

    # C++ standard library (cross-compiled into TOOL_DIR/usr).
    nls=no multilib=no prefix=$TOOL_DIR package_install_dir=$TOOL_DIR install gcc#libstdc++

    # --- Temporary tools (glibc-linked, relocatable) ---------------

    (
        host=$target
        prefix=$TOOL_DIR
        nls=no

        werror=no install m4
        install ncurses#tic
        normal=no cxx=no stripping=no install ncurses
        curses=no install bash
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
        chfn_chsh=no login=no nologin=no su=no setpriv=no runuser=no \
            liblastlog2=no ncurses=no ncursesw=no tinfo=no wall=no \
            makeinstall_chown=no install util-linux
    )

    # Binutils pass 2: native (glibc-linked) linker/assembler.
    package_variant=pass2 \
        host=$target prefix=/usr sysroot=$TOOL_DIR \
        package_install_dir=$TOOL_DIR gprofng=no nls=no werror=no install binutils

    # GCC pass 2: native compiler for the target (glibc-linked, Canadian cross).
    package_variant=pass2 \
        host=$target prefix=/usr sysroot=$TOOL_DIR build_sysroot=$TOOL_DIR \
        package_install_dir=$TOOL_DIR \
        glibc_version=2.43 languages=c,c++ multilib=no \
        shared=yes threads=yes libstdcxx=yes \
        nls=no fixincludes=no \
        libatomic=no libgomp=no libquadmath=no libsanitizer=no libssp=no libvtv=no \
        install gcc
}

tools_build() {
    (
        host=$target
        prefix=$TOOL_DIR
        nls=no

        install gettext
    )
    # Runs in the scratch container (or bare host) using only the toolchain.
    # Phase 2: native builds that dogfood the bootstrapped toolchain.
    #host=$target prefix=/usr package_install_dir=$TOOL_DIR install coreutils
}
