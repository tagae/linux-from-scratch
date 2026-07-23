# Umbrella meta-package: everything needed for a bootable systemd system.
# `INIT=systemd ./lfs system build` installs this (bootable-$INIT); it
# pulls in the members below, in order, into the platform's target tree.
# It has no payload of its own — package_meta=yes tells the framework
# depends() is the whole recipe (see _install in lib/package.sh). The
# install scenario (host/prefix/package_variant/package_install_dir) is set
# once by install()/target_build_env and inherited by every member; only
# the per-member knobs that differ from a package's upstream defaults are
# set here, exactly as build_tools() tweaks knobs for its own members.
#
# The busybox-init flavor is the sibling umbrella bootable-busybox.sh — a
# shorter member list (no glibc/util-linux/systemd, since busybox is static).
#
# A version is required only because the framework derives every package's
# work/stamp paths from it (there is no source to download).
: ${package_version:=0.1.0}
package_meta=yes

depends() {
    # Root filesystem skeleton and merged-usr symlinks. Must come first:
    # every later member installs through the /bin -> usr/bin etc. links it
    # lays down.
    require system-files

    # CA trust store, so TLS clients on the target system (e.g. wget, once
    # installed by hand) have real root certificates to verify against.
    # make-ca/p11-kit's `trust` are build-host-native tools (only ever
    # installed into $TOOL_DIR, on PATH here — see package/ca-certificates.sh
    # and lib/tools.sh's build_tools); only the generated, architecture-
    # independent PEM bundle itself lands in this target tree.
    require ca-certificates

    # glibc's build shells out to bison, whose compiled-in default
    # pkgdatadir is the literal /usr/share/bison (this container's real
    # root, not TOOL_DIR-relative); point it at our own. headers=: the
    # per-target sysroot's kernel headers ($TOOL_DIR/$target), matching
    # $target's architecture.
    (
        export BISON_PKGDATADIR=$TOOL_DIR/usr/share/bison
        headers=$TOOL_DIR/$target/usr/include require glibc
    )

    # Capabilities.
    require libcap

    # Kernel module loading (no man pages in this minimal build).
    ( manpages=no require kmod )

    # Shell and core utilities.
    require busybox

    # Core userspace utilities (agetty, mount, login, …). Busybox already
    # provides chfn/chsh/login/nologin/su, and there's no Python/systemd
    # integration wanted here. bindir/sbindir/libdir must be explicit:
    # configure's own libdir default is the legacy split-usr /lib, but
    # system-files' merged-usr layout makes /lib and /usr/lib the same
    # directory via symlink, so its post-install "move essential libs to
    # /lib" hook would fail (source == destination). makeinstall_chown=no /
    # makeinstall_setuid=no: `chown root:root`/setuid on mount fail here
    # (no /etc/passwd for "root"), and setuid-to-build-UID is actively wrong
    # (see feedback-util-linux-setuid). util-linux links its own just-
    # installed libmount/libblkid, so its script opts into the sysroot CC
    # (target_sysroot_cc) — nothing to set here for that.
    (
        bindir=/usr/bin sbindir=/usr/sbin libdir=/usr/lib
        chfn_chsh=no login=no nologin=no su=no setpriv=no runuser=no
        pylibmount=no static=no liblastlog2=no python=no systemd=no wall=no
        makeinstall_chown=no makeinstall_setuid=no
        require util-linux
    )

    # Init system; sysroot points meson/pkg-config at what earlier members
    # installed into the target tree (libcap, util-linux's libmount/libblkid, …).
    # $INSTALL_DIR/$SYSTEM_KEY, not bare $PLATFORM: with the stage->archive
    # ->merge inversion (PACKAGING.md), package_install_dir is now each
    # member's own per-package stage dir — $INSTALL_DIR/$SYSTEM_KEY (=
    # package_merge_dir, see target_build_env) is the one path that still
    # names the actual merged tree these earlier members landed in, and is
    # also what target_sysroot_cc (util-linux) already points at. Bare
    # $PLATFORM silently diverges from that whenever $CAPS is non-empty
    # (SYSTEM_KEY folds CAPS in, see lfs) — same tree only by coincidence
    # for the default no-caps build.
    ( sysroot=$INSTALL_DIR/$SYSTEM_KEY require systemd )

    # Opt-in capabilities (see lfs's Capabilities section for CAPS). Must
    # come after systemd above: network-config reverses part of systemd.sh's
    # own install()-time masking, so it has to run after that masking exists
    # to reverse. Absent from CAPS (the default), neither require() below
    # ever runs, so a no-caps build is unaffected.
    case " ${CAPS:-} " in
        *" network "*) require network-config ;;
    esac
    case " ${CAPS:-} " in
        *" 9p "*) require 9p-config ;;
    esac

    # Kernel image, DTBs and modules. BISON_PKGDATADIR: the kernel's kconfig
    # parser generation (allnoconfig/olddefconfig, in linux.sh's prepare())
    # shells out to bison, whose compiled-in default pkgdatadir is the
    # literal /usr/share/bison — this container's empty real root, not
    # TOOL_DIR-relative (same fixup as glibc above; see there).
    ( export BISON_PKGDATADIR=$TOOL_DIR/usr/share/bison; require linux )

    # Boot partition files (cmdline.txt + config.txt) — Pi platforms only.
    if [ -n "${DTB:-}" ]; then
        require boot#cmdline
        require boot#config
    fi
}
