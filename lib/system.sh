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

    # Capabilities — hard systemd dependency
    install libcap

    # Kernel module loading — hard systemd dependency
    manpages=no install kmod

    # Shell and core utilities.
    install busybox

    # Core userspace utilities (agetty, mount, login, …). Busybox already
    # provides chfn/chsh/login/nologin/su, and there's no Python/systemd
    # integration wanted in this minimal build. bindir/sbindir/libdir must
    # be explicit: configure's own default for libdir is the legacy
    # split-usr /lib, but system-files' merged-usr layout makes /lib and
    # /usr/lib the same directory via symlink — its post-install hook that
    # moves "essential" libs into /lib then fails, since source and
    # destination are identical. makeinstall_chown=no skips `chown
    # root:root` on mount for setuid, which fails outright here anyway —
    # there's no /etc/passwd for "root" to resolve against.
    bindir=/usr/bin sbindir=/usr/sbin libdir=/usr/lib \
    chfn_chsh=no login=no nologin=no su=no setpriv=no runuser=no \
    pylibmount=no static=no liblastlog2=no python=no systemd=no wall=no \
    makeinstall_chown=no \
        install util-linux

    # Init system. sysroot points meson/pkg-config at what we've installed
    # into INSTALL_DIR so far (libcap, util-linux's libmount/libblkid, …).
    sysroot=$INSTALL_DIR install systemd

    exit 0

    # Kernel image, DTBs and modules
    install linux

    # Boot partition files (cmdline.txt + config.txt) — Pi platforms only
    if [ -n "${DTB:-}" ]; then
        package_install_dir=$INSTALL_DIR \
            install boot#cmdline

        package_install_dir=$INSTALL_DIR \
            install boot#config
    fi
}
