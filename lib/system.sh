_sys() {
    host=$target \
    prefix=/usr \
    sysroot=$INSTALL_DIR \
    package_install_dir=$INSTALL_DIR \
    package_variant=final \
    install "$@"
}

system() {
    # Kernel headers
    package_install_dir=$INSTALL_DIR \
    package_variant=final \
        install linux#headers

    # Basic directory structure and static /etc files
    _sys system-files

    # C library — must come before anything that links dynamically
    host=$target \
    prefix=/usr \
    sysroot=$INSTALL_DIR \
    headers=$INSTALL_DIR/usr/include \
    package_install_dir=$INSTALL_DIR \
    package_variant=final \
        install glibc

    # Capabilities — hard systemd dependency
    _sys libcap

    # Kernel module loading — hard systemd dependency
    _sys kmod

    # GCC runtime libraries — cross-compiler sysroot is $INSTALL_DIR but the
    # target libs land in $TOOL_DIR/$target/lib or lib64 (arch-dependent).
    # Detect which directory holds the actual shared libraries.
    _tgt_lib=$TOOL_DIR/$target/lib
    [ -f $_tgt_lib/libgcc_s.so.1 ] || _tgt_lib=$TOOL_DIR/$target/lib64
    cp -v $_tgt_lib/libgcc_s.so.1 $INSTALL_DIR/usr/lib/
    ln -sfv libgcc_s.so.1 $INSTALL_DIR/usr/lib/libgcc_s.so
    for f in $_tgt_lib/libatomic.so.*.*; do
        cp -v $f $INSTALL_DIR/usr/lib/
        _ver=${f##*/libatomic.so.}
        ln -sfv libatomic.so.$_ver $INSTALL_DIR/usr/lib/libatomic.so.${_ver%%.*}
        ln -sfv libatomic.so.${_ver%%.*} $INSTALL_DIR/usr/lib/libatomic.so
    done
    # libstdc++ lands in $TOOL_DIR/usr/lib (or lib64 via symlink) after gcc#libstdc++
    for f in $TOOL_DIR/usr/lib/libstdc++.so.*.*; do
        case $f in *.py) continue;; esac
        cp -v $f $INSTALL_DIR/usr/lib/
        ver=${f##*/libstdc++.so.}
        major=${ver%%.*}
        ln -sfv libstdc++.so.$ver $INSTALL_DIR/usr/lib/libstdc++.so.$major
        ln -sfv libstdc++.so.$major $INSTALL_DIR/usr/lib/libstdc++.so
    done

    # Shell and core utilities — statically linked, no further deps
    _sys busybox

    # Core userspace utilities (agetty, mount, login, …)
    _sys util-linux

    # Init system
    _sys systemd

    # Kernel image, DTBs and modules
    package_install_dir=$INSTALL_DIR \
    package_variant=final \
        install linux

    # Boot partition files (cmdline.txt + config.txt) — Pi platforms only
    if [ -n "${DTB:-}" ]; then
        package_install_dir=$INSTALL_DIR \
            install boot#cmdline

        package_install_dir=$INSTALL_DIR \
            install boot#config
    fi
}
