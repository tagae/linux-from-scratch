tools() {
    platform "$1"

    readonly prefix=$TOOL_DIR
    readonly sysroot=$TOOL_DIR
    package_install_dir=/

    gprofng=no install binutils
    package_install_dir=$TOOL_DIR install linux#headers
    newlib=yes headers=no shared=no threads=no libatomic=no libgomp=no libquadmath=no \
               build_sysroot=$TOOL_DIR build_time_sysroot=$TOOL_DIR install gcc

    # Use built cross compiler.
    PATH=$TOOL_DIR/bin:$TOOL_DIR/usr/bin:$PATH

    readonly headers=$TOOL_DIR/usr/include

    install glibc
    install gcc

    # Check sanity.
    echo 'int main(){}' | LD_LIBRARY_PATH=$TOOL_DIR/lib ./tools/bin/arm-scratch-linux-gnueabihf-gcc -xc -
    readelf -l a.out | grep ld-linux
}
