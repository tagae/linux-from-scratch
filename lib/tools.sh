tools() {
    # Cross-binutils: runs on host, produces code for target
    prefix=$TOOL_DIR sysroot=$INSTALL_DIR package_install_dir=/ gprofng=no install binutils

    # GCC pass 1: minimal compiler (newlib, no shared libs) for building glibc headers
    package_variant=pass1 \
        prefix=$TOOL_DIR sysroot=$TOOL_DIR package_install_dir=/ \
        newlib=yes headers=no shared=no \
        threads=no libatomic=no libgomp=no libquadmath=no libssp=no libvtv=no libstdcxx=no \
        install gcc

    # Linux kernel headers (for glibc to reference; /usr appended by linux.sh)
    package_install_dir=$TOOL_DIR install linux#headers

    # Glibc: cross-compiled C library, installed into tools sysroot
    MAKE=make \
        package_install_dir=$TOOL_DIR \
        headers=$TOOL_DIR/usr/include \
        shared=yes \
        install glibc

    # On aarch64 without --libdir, glibc installs startup objects to usr/lib64.
    # Create usr/lib → lib64 so the cross-compiler's sysroot search path resolves them.
    [ -e $TOOL_DIR/usr/lib ] || ln -s lib64 $TOOL_DIR/usr/lib

    # Sanity check: verify cross-compiler produces correct dynamic linker reference.
    # --sysroot=$TOOL_DIR: works whether gcc pass1 or the final gcc is in $TOOL_DIR/bin.
    # -fno-link-libatomic: suppresses -latomic_asneeded (a GCC 16 spec addition)
    #   so the check doesn't fail when libatomic hasn't been installed yet.
    echo 'int main(){}' | $TOOL_DIR/bin/$target-gcc --sysroot=$TOOL_DIR -fno-link-libatomic -xc -
    readelf -l a.out > a.txt
    grep ld-linux a.txt
    rm -f a.out a.txt

    # libstdc++: C++ standard library for the target
    package_install_dir=$TOOL_DIR install gcc#libstdc++
    rm -fv \
       $TOOL_DIR/usr/lib/libstdc++.la \
       $TOOL_DIR/usr/lib/libstdc++exp.la \
       $TOOL_DIR/usr/lib/libstdc++fs.la \
       $TOOL_DIR/usr/lib/libsupc++.la

    # GCC final: full cross-compiler, sysroot points to final install dir
    # so that packages built in the system phase link against the final glibc.
    # build_sysroot=$TOOL_DIR directs GCC's own build (fixincludes, libgcc) to
    # the tools sysroot where glibc already lives.
    prefix=$TOOL_DIR sysroot=$INSTALL_DIR build_sysroot=$TOOL_DIR package_install_dir=/ install gcc

    # Coreutils for the toolchain (provides basic utilities during system build)
    package_install_dir=$TOOL_DIR install coreutils
}
