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

    # Linux kernel headers to build glibc.
    package_install_dir=$TOOL_DIR install linux#headers

    # GNU C library: the glibc that all toolchain binaries will link against.
    # Lives under TOOL_DIR/usr (like real LFS's $LFS/usr), not TOOL_DIR itself:
    # its own absolute self-references (e.g. the libc.so linker script) are
    # prefix-relative, and get sysroot-prefixed by TOOL_DIR again at link time.
    # If prefix were TOOL_DIR too, that would double up the path.
    package_install_dir=$TOOL_DIR \
        prefix=/usr \
        nscd=no kernel=5.10 werror=no \
        install glibc

    # Verify the cross-compiler references our glibc dynamic linker.
    echo 'int main(){}' | $TOOL_DIR/bin/$target-gcc -x c - -v -Wl,--verbose
    readelf -l a.out | grep -q ld-linux || bail "Cross-compiler does not use glibc ld"
    rm -f a.out

    # C++ standard library (cross-compiled into TOOL_DIR/usr, same reasoning as glibc above).
    package_install_dir=$TOOL_DIR \
        prefix=/usr \
        multilib=no nls=no libstdcxx_pch=no \
        install gcc#libstdc++

    # --- Temporary tools (glibc-linked, relocatable) ---------------

    (
        # --build must be explicit: with only --host given, autoconf sets
        # cross_compiling=maybe and falls back to actually running a test
        # binary. Since target and build are the same architecture here,
        # that test binary runs "successfully" against the host's own libc,
        # so cross_compiling is wrongly resolved to "no" — and packages then
        # try to run their (incompatible, newer-glibc) freshly built binaries
        # directly, e.g. coreutils' man-page generation via help2man.
        build=$(cc -dumpmachine)
        host=$target
        package_install_dir=$TOOL_DIR
        prefix=/usr
        nls=no

        install m4
        package_install_dir=/ prefix=$TOOL_DIR install ncurses#tic
        shared=yes normal=no cxx_shared=yes debug=no ada=no stripping=no install ncurses
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

    tools_relocate
}

# Everything under TOOL_DIR/usr (glibc, libstdc++, temp tools, pass2
# binutils/gcc) was built against our own glibc but still carries the
# bootstrap container's default dynamic linker path, since --sysroot only
# affects compile-time search, not the interpreter string baked into the
# ELF. That's invisible here (same architecture as the host), but breaks
# once TOOL_DIR is mounted into the `scratch` image, which has nothing else
# in it. Repoint every ELF at our own dynamic linker and libraries.
#
# TOOL_DIR/bin (pass1 binutils/gcc) is deliberately excluded: it's a
# throwaway, host-native toolchain used only to bootstrap glibc/pass2 here
# in the bootstrap container, and is linked against the host's own glibc —
# relocating it would break it for no benefit, since it's not part of the
# self-contained toolchain the `scratch` image runs.
tools_relocate() {
    stage "Relocating toolchain binaries under $TOOL_DIR/usr"

    local ld_so=$(find $TOOL_DIR/usr/lib -maxdepth 1 -name 'ld-linux-*.so.*' | head -1)
    [ -n "$ld_so" ] || bail "Cannot find dynamic linker to relocate against"
    local lib_dir=$(dirname $ld_so)

    # The dynamic linker itself is excluded by name pattern directly in find
    # (rather than compared against $ld_so per file) since it's self-
    # referential (its own .interp points at itself) and patchelf reliably
    # corrupts that; every other binary's PT_INTERP is what makes it findable.
    # glibc installs it under two names — the soname in usr/lib, and a
    # usr/bin/ld.so convenience copy — both need excluding.
    find $TOOL_DIR/usr \( -type f -perm -u+x -o -name '*.so' -o -name '*.so.*' \) \
        -not -name 'ld-linux-*.so.*' -not -name 'ld.so' -print |
    while IFS= read -r f; do
        [ "$(head -c4 "$f" 2>/dev/null | od -An -tx1 | tr -d ' \n')" = 7f454c46 ] || continue
        readelf -d "$f" 2>/dev/null | grep -q 'Dynamic section' || continue
        readelf -l "$f" 2>/dev/null | grep -q ' INTERP ' \
            && patchelf --set-interpreter $ld_so "$f"
        patchelf --set-rpath $lib_dir "$f"
    done

    find $TOOL_DIR/usr \( -name 'ld-linux-*.so.*' -o -name 'ld.so' \) |
    while IFS= read -r f; do
        readelf -d "$f" 2>/dev/null | grep -q RUNPATH \
            && bail "Dynamic linker $f was itself relocated — this breaks it"
    done

    return 0
}

tools_build() {
    (
        package_install_dir=$TOOL_DIR
        prefix=/usr
        nls=no

        install gettext
    )

    tools_relocate
}
