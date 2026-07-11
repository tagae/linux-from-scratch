system() {
    case "${1:-help}" in
        build) build_system ;;
        help)
            echo "Usage: $(basename "$0") system build"
            if [ $# -eq 1 ]; then exit 0; else exit 1; fi
            ;;
        *) bail "Unknown command '$1'" ;;
    esac
}

build_system() {
    host=$target
    package_install_dir=$INSTALL_DIR
    prefix=/usr

    install system-files

    # Kernel headers glibc builds its syscall wrappers against. These are
    # only a build-time dependency (glibc doesn't ship them), so install
    # into TOOL_DIR rather than INSTALL_DIR — the shipped image should
    # have no header files at all, and this way they never need stripping
    # back out.
    #package_install_dir=$TOOL_DIR install linux#headers

    # glibc's own build invokes bison (e.g. for intl/plural.y) as an
    # external tool. bison was built with --prefix=/usr (landing under
    # TOOL_DIR via DESTDIR), but its own compiled-in default pkgdatadir is
    # the literal /usr/share/bison (this container's real root, not
    # TOOL_DIR-relative) — it has no notion of TOOL_DIR as a DESTDIR any
    # more than pkgconf did.
    export BISON_PKGDATADIR=$TOOL_DIR/usr/share/bison

    headers=$TOOL_DIR/usr/include install glibc

    exit 0

    # Capabilities — hard systemd dependency
    install libcap
    # Kernel module loading — hard systemd dependency
    install kmod

    # Shell and core utilities.
    install busybox

    # Core userspace utilities (agetty, mount, login, …)
    install util-linux

    # Init system
    install systemd

    # Kernel image, DTBs and modules
    package_install_dir=$INSTALL_DIR install linux

    # Boot partition files (cmdline.txt + config.txt) — Pi platforms only
    if [ -n "${DTB:-}" ]; then
        package_install_dir=$INSTALL_DIR \
            install boot#cmdline

        package_install_dir=$INSTALL_DIR \
            install boot#config
    fi
}
