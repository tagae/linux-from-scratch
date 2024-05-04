tools() {
    prefix=$TOOL_DIR sysroot=$INSTALL_DIR package_install_dir=/ gprofng=no install binutils

    prefix=$TOOL_DIR sysroot=$TOOL_DIR package_install_dir=/ \
        headers=$TOOL_DIR/include newlib=yes headers=no shared=no \
        threads=no libatomic=no libgomp=no libquadmath=no libssp=no libvtv=no libstdcxx=no \
        install gcc

    # Use built cross compiler.
    PATH=$TOOL_DIR/bin:$TOOL_DIR/usr/bin:$PATH

    package_install_dir=$TOOL_DIR/usr install linux#headers

    MAKE=make \
        package_install_dir=$TOOL_DIR \
        headers=$TOOL_DIR/usr/include \
        shared=yes \
        install glibc

    # Check sanity.
    echo 'int main(){}' | ./tools/bin/arm-scratch-linux-gnueabihf-gcc -xc -
    readelf -l a.out > a.txt
    grep ld-linux < a.txt
}
