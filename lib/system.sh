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
    # $INSTALL_DIR/$PLATFORM, not bare $INSTALL_DIR: package_variant below
    # already disambiguates the install *stamp* per platform (so switching
    # PLATFORM correctly triggers a fresh install rather than being skipped
    # as "already done"), but the install *destination* also has to be
    # keyed by platform, the same way lib/tools.sh keys its own
    # package_install_dir=$TOOL_DIR/$target. Without this, every platform's
    # build still lands in the one shared $INSTALL_DIR: fine the first time
    # any given platform is built, but revisiting an already-stamped
    # platform after a different one has run in between skips install()
    # (its stamp already exists) while $INSTALL_DIR still holds that other,
    # more recent platform's files — e.g. an aarch64 kernel/systemd/etc.
    # silently left in place for a supposedly-pi0 (arm) build.
    package_install_dir=$INSTALL_DIR/$PLATFORM
    prefix=/usr
    package_variant=$PLATFORM

    install system-files

    # glibc's own build invokes bison as an  external tool.
    # bison was built with --prefix=/usr (landing under TOOL_DIR via DESTDIR),
    # but its own compiled-in default pkgdatadir is the literal /usr/share/bison
    # (this container's real root, not TOOL_DIR-relative).
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
    #
    # CC must target INSTALL_DIR's own glibc explicitly, not gcc's default
    # $TOOL_DIR/$target sysroot: util-linux's `make install` DESTDIR-installs
    # several interdependent libtool libraries (libmount needs libblkid,
    # etc.), which makes libtool relink them, adding an explicit
    # "-L$INSTALL_DIR/usr/lib" ahead of gcc's own default library search
    # path. ld then resolves the implicit "-lc" against INSTALL_DIR's own
    # glibc — but glibc's libc.so is an ld script with bare absolute paths
    # (GROUP ( /usr/lib/libc.so.6 ... )), which without --sysroot resolve
    # against the container's real root instead of INSTALL_DIR: the scratch
    # container bind-mounts TOOL_DIR/usr/lib (the toolchain's native,
    # build-host-arch runtime) onto /usr/lib, a mismatch invisible on
    # aarch64 targets (native happens to be the same arch as the target)
    # but a hard "file format not recognized" on pi0 (arm). -idirafter
    # keeps the target sysroot's kernel headers reachable, since
    # INSTALL_DIR itself carries none (see systemd below).
    bindir=/usr/bin sbindir=/usr/sbin libdir=/usr/lib \
    chfn_chsh=no login=no nologin=no su=no setpriv=no runuser=no \
    pylibmount=no static=no liblastlog2=no python=no systemd=no wall=no \
    makeinstall_chown=no makeinstall_setuid=no \
    CC="$target-gcc --sysroot=$INSTALL_DIR/$PLATFORM -idirafter $TOOL_DIR/$target/usr/include" \
    install util-linux

    # Init system; sysroot points meson/pkg-config at what we've installed
    # into INSTALL_DIR/$PLATFORM so far (libcap, util-linux's libmount/libblkid, …).
    sysroot=$INSTALL_DIR/$PLATFORM install systemd

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
    cp -v $INSTALL_DIR/$PLATFORM/boot/kernel.img $WORK_DIR/boot/
    if [ -n "${DTB:-}" ]; then
        mkdir -p $WORK_DIR/boot/$(dirname $DTB)
        cp -v $INSTALL_DIR/$PLATFORM/boot/$DTB $WORK_DIR/boot/$DTB
    fi
}
