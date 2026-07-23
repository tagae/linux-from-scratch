# Umbrella meta-package: a bootable Busybox-only system, with busybox as
# PID 1 (its init applet). `INIT=busybox ./lfs system build` installs this.
# Sibling of bootable-systemd.sh; see it and lib/package.sh for how umbrella
# meta-packages work.
#
# Far shorter member list than the systemd flavor: busybox is built static
# (CONFIG_STATIC=y in package/busybox.sh), so there is no glibc to install,
# and busybox's own applets replace util-linux (mount/getty/login/…), kmod
# and systemd. busybox's `make install` lays down /sbin/init -> busybox;
# with no systemd to overwrite it (as happens in the systemd flavor), that
# symlink is what the kernel executes as PID 1.
: ${package_version:=0.1.0}
package_meta=yes

depends() {
    # Root filesystem skeleton and merged-usr symlinks — first, so later
    # members install through the /bin -> usr/bin etc. links it lays down.
    require system-files

    # CA trust store — see bootable-systemd.sh for why this is safe and
    # cheap even in this static, glibc-less flavor (no runtime dependency
    # on the target at all, just PEM files).
    require ca-certificates

    # Shell, core utilities, and the init/getty/login/mount/poweroff applets.
    require busybox

    # /etc/inittab + /etc/init.d/rcS driving busybox init (getty on the
    # platform's serial console).
    require busybox-init

    # Opt-in capabilities (see lfs's Capabilities section for CAPS). Placed
    # after busybox-init above since both members' busybox halves drop a
    # script into the /etc/init.d it creates. Absent from CAPS (the
    # default), neither require() below ever runs, so a no-caps build is
    # unaffected.
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
    # TOOL_DIR-relative (see bootable-systemd.sh's glibc install for the
    # same fixup).
    ( export BISON_PKGDATADIR=$TOOL_DIR/usr/share/bison; require linux )

    # Boot partition files (cmdline.txt + config.txt) — Pi platforms only,
    # for real hardware; QEMU loads the kernel directly and ignores them.
    if [ -n "${DTB:-}" ]; then
        require boot#cmdline
        require boot#config
    fi
}
