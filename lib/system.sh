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

    # glibc's own build invokes bison (e.g. for intl/plural.y) as an
    # external tool. bison was built with --prefix=/usr (landing under
    # TOOL_DIR via DESTDIR), but its own compiled-in default pkgdatadir is
    # the literal /usr/share/bison (this container's real root, not
    # TOOL_DIR-relative) — it has no notion of TOOL_DIR as a DESTDIR any
    # more than pkgconf did.
    export BISON_PKGDATADIR=$TOOL_DIR/usr/share/bison

    # TOOL_DIR/$target, not TOOL_DIR/usr: the per-target sysroot holds
    # this platform's own kernel headers, matching $target's architecture
    # — TOOL_DIR/usr holds the build-host-native toolchain's headers
    # instead, a different architecture entirely on e.g. pi0.
    headers=$TOOL_DIR/$target/usr/include install glibc

    # Capabilities.
    install libcap

    # Kernel module loading.
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
    # makeinstall_setuid=no: without also disabling this, `make install`
    # still chmod u+s's mount/umount despite the chown above being
    # skipped — leaving them setuid to the *build* UID, not root, which
    # is actively wrong (and leaves mount unusable for anyone but root).
    bindir=/usr/bin sbindir=/usr/sbin libdir=/usr/lib \
    chfn_chsh=no login=no nologin=no su=no setpriv=no runuser=no \
    pylibmount=no static=no liblastlog2=no python=no systemd=no wall=no \
    makeinstall_chown=no makeinstall_setuid=no \
    install util-linux

    # Init system; sysroot points meson/pkg-config at what we've installed
    # into INSTALL_DIR so far (libcap, util-linux's libmount/libblkid, …).
    sysroot=$INSTALL_DIR install systemd

    # Kernel image, DTBs and modules
    install linux

    # Boot partition files (cmdline.txt + config.txt) — Pi platforms only
    if [ -n "${DTB:-}" ]; then
        install boot#cmdline
        install boot#config
    fi

    # `./lfs qemu` runs directly on the host, not in a container — INSTALL_DIR
    # is a Docker volume the host can't see at all. WORK_DIR/boot is bind-
    # mounted to the host (see docker-compose.yaml) specifically so the
    # kernel (and DTB, for Pi platforms tested under QEMU) end up somewhere
    # the host-side `qemu` command can actually read.
    mkdir -p $WORK_DIR/boot
    cp -v $INSTALL_DIR/boot/kernel.img $WORK_DIR/boot/
    if [ -n "${DTB:-}" ]; then
        mkdir -p $WORK_DIR/boot/$(dirname $DTB)
        cp -v $INSTALL_DIR/boot/$DTB $WORK_DIR/boot/$DTB
    fi
}
