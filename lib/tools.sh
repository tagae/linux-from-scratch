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

_ch6() {
    host=$target prefix=/usr package_install_dir=$TOOL_DIR install "$@"
}

# Install a GCC specs file so every binary the compiler produces is
# relocatable to $TOOL_DIR (absolute interpreter path + rpath).
_install_specs() {
    # Write a GCC specs file so produced binaries use the toolchain's ld.so.
    # *link_dynamic_linker: is not a real GCC spec; use *link: + instead.
    # Appending -dynamic-linker overrides the built-in default (last flag wins in ld).
    local gcc=$1 libdir ldso
    libdir=$(dirname $($gcc -print-libgcc-file-name))
    ldso=$(ls $TOOL_DIR/lib/ld-linux*.so.* 2>/dev/null | head -1)
    [ -n "$ldso" ] || bail "Cannot find ld-linux*.so in $TOOL_DIR/lib"
    printf '*link:\n+ -dynamic-linker %s -rpath %s -rpath %s\n\n' \
        "$ldso" "$TOOL_DIR/lib" "$TOOL_DIR/usr/lib" > "$libdir/specs"
}

tools_bootstrap() {
    # --- Skeleton: merged-usr layout + minimal /etc ---------------------------
    mkdir -p $TOOL_DIR/usr/bin $TOOL_DIR/usr/lib $TOOL_DIR/usr/include \
             $TOOL_DIR/usr/sbin $TOOL_DIR/usr/share $TOOL_DIR/etc \
             $TOOL_DIR/root $TOOL_DIR/tmp
    ln -sfv usr/bin  $TOOL_DIR/bin
    ln -sfv usr/sbin $TOOL_DIR/sbin
    ln -sfv usr/lib  $TOOL_DIR/lib
    ln -sfv usr/lib  $TOOL_DIR/lib64

    printf 'root:x:0:0:root:/root:/bin/sh\n'        > $TOOL_DIR/etc/passwd
    printf 'root:x:0:\nbin:x:1:\nutmp:x:13:\n'      > $TOOL_DIR/etc/group
    printf 'passwd: files\ngroup: files\nhosts: files dns\n' \
                                                     > $TOOL_DIR/etc/nsswitch.conf

    # --- Chapter 5: cross-toolchain (musl-linked, throwaway) ------------------

    # Binutils pass 1: cross-assembler/linker.
    prefix=$TOOL_DIR/cross sysroot=$TOOL_DIR package_install_dir=/ \
        gprofng=no install binutils

    # GCC pass 1: minimal C cross-compiler for building glibc.
    package_variant=pass1 \
        prefix=$TOOL_DIR/cross sysroot=$TOOL_DIR package_install_dir=/ \
        newlib=yes headers=no shared=no \
        threads=no libatomic=no libgomp=no libquadmath=no libssp=no \
        libvtv=no libstdcxx=no libsanitizer=no \
        install gcc

    # Plain-name symlinks for assembler/linker tools used by the cross-compiler.
    # Do NOT symlink gcc/cc: that would shadow Alpine's native CC_FOR_BUILD
    # and cause build-side programs to be compiled with the cross-compiler.
    for _t in ar as ld nm objcopy objdump ranlib readelf strip; do
        ln -sfv $target-$_t $TOOL_DIR/cross/bin/$_t
    done

    # Linux kernel headers (glibc needs them).
    package_install_dir=$TOOL_DIR install linux#headers

    # GNU C library: the glibc that all toolchain binaries will link against.
    prefix=/usr headers=$TOOL_DIR/usr/include \
        package_install_dir=$TOOL_DIR install glibc

    # Verify the cross-compiler references our glibc dynamic linker.
    echo 'int main(){}' | \
        $TOOL_DIR/cross/bin/$target-gcc --sysroot=$TOOL_DIR \
        -fno-link-libatomic -xc -
    readelf -l a.out | grep -q ld-linux || bail "Cross-compiler does not use glibc ld"
    rm -f a.out

    # Fix GCC pass1's newlib-configured internal limits.h:
    # 1. MB_LEN_MAX was baked as 1 (newlib); glibc requires 16.
    # 2. The file has no #include_next, so glibc POSIX extensions
    #    (_POSIX_ARG_MAX, PATH_MAX, …) are never visible.
    #    Chain to glibc's limits.h via #include_next, but first define
    #    _GCC_LIMITS_H_ so glibc's own #include_next guard does not fire.
    _gcc_lib=$(dirname $($TOOL_DIR/cross/bin/$target-gcc -print-libgcc-file-name))
    sed -i \
        -e 's/^#define MB_LEN_MAX 1$/#define MB_LEN_MAX 16/' \
        -e '/^#endif.*_LIMITS_H___/{i\#define _GCC_LIMITS_H_\
#include_next <limits.h>
}' \
        $_gcc_lib/include/limits.h

    # Install the specs file so all subsequent cross-compiled binaries are
    # relocatable to $TOOL_DIR (absolute interpreter + rpath).
    _install_specs $TOOL_DIR/cross/bin/$target-gcc

    # C++ standard library (cross-compiled into TOOL_DIR/usr).
    package_install_dir=$TOOL_DIR install gcc#libstdc++

    # GCC pass1 (prefix=TOOL_DIR/cross) looks for C++ headers at
    # cross/$target/include/c++/VERSION; symlink to where libstdc++ installed them.
    _gcc_ver=$($TOOL_DIR/cross/bin/$target-gcc -dumpversion)
    mkdir -p $TOOL_DIR/cross/$target/include/c++
    rm -f $TOOL_DIR/cross/$target/include/c++/$_gcc_ver 2>/dev/null || true
    ln -sf $TOOL_DIR/usr/include/c++/$_gcc_ver \
           $TOOL_DIR/cross/$target/include/c++/$_gcc_ver

    # --- Chapter 6: temporary tools (glibc-linked, relocatable) ---------------

    _ch6 m4
    _ch6 ncurses
    _ch6 bash
    _ch6 coreutils
    _ch6 diffutils
    _ch6 file
    _ch6 findutils
    _ch6 gawk
    _ch6 grep
    _ch6 gzip
    _ch6 make
    _ch6 patch
    _ch6 sed
    _ch6 tar
    _ch6 xz

    # Binutils pass 2: native (glibc-linked) linker/assembler.
    # Use package_variant=pass2 to get a separate work dir from pass1.
    package_variant=pass2 \
        host=$target prefix=/usr sysroot=$TOOL_DIR \
        package_install_dir=$TOOL_DIR gprofng=no install binutils

    # GCC pass 2: native compiler for the target (glibc-linked, Canadian cross).
    # No build_sysroot: let build-side generator tools use Alpine's musl headers
    # so they link against musl (not glibc), avoiding __isoc23_strtoul mismatches.
    host=$target \
        prefix=/usr sysroot=$TOOL_DIR \
        package_install_dir=$TOOL_DIR \
        libsanitizer=no \
        install gcc
    # Ensure plain gcc/cc exist (Canadian cross may only install $target-gcc).
    [ -f $TOOL_DIR/usr/bin/gcc ] || ln -sfv $target-gcc $TOOL_DIR/usr/bin/gcc
    [ -f $TOOL_DIR/usr/bin/cc  ] || ln -sfv gcc          $TOOL_DIR/usr/bin/cc
    _install_specs $TOOL_DIR/usr/bin/$target-gcc

    # util-linux: provides getopt, needed by ./lfs to parse args in phase 2.
    _ch6 util-linux

    # Patch every glibc-linked ELF in the toolchain to use the toolchain's ld.so.
    # The specs fix makes new builds correct; this fixes binaries already built with
    # the wrong (system-default) interpreter path.
    stage "Patching toolchain ELF interpreters"
    _ldso=$(ls $TOOL_DIR/lib/ld-linux*.so.* | head -1)
    find $TOOL_DIR -type f ! -type l | while read _f; do
        readelf -l "$_f" 2>/dev/null | grep -q 'ld-linux' || continue
        patchelf --set-interpreter "$_ldso" \
                 --set-rpath "$TOOL_DIR/lib:$TOOL_DIR/usr/lib" \
                 "$_f" 2>/dev/null || true
    done
}

tools_build() {
    # Runs in the scratch container (or bare host) using only the toolchain.
    # Phase 2: native builds that dogfood the bootstrapped toolchain.
    # Proof of self-sufficiency: compile coreutils natively.
    host=$target prefix=/usr package_install_dir=$TOOL_DIR install coreutils
}
