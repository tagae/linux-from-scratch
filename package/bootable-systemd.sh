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
    #
    # Both are TOOL_DIR-relative paths that only exist in the container —
    # on the guest (LFS_PHASE=guest, SELF-HOST.md M4) there is no TOOL_DIR
    # at all (see lfs), so $TOOL_DIR resolves to the 9p-shared project
    # dir's nonexistent "tools" subdir. Guarded with [ -d ... ], not an
    # LFS_PHASE check: it's the same condition either way (only true in the
    # container) but self-documents WHY, and needs no phase-var lookup.
    # Left unset there, both fall back to already-correct native defaults:
    # bison's own compiled-in /usr/share/bison is real on the guest (it was
    # itself installed with prefix=/usr — see SELF-HOST.md M3), and plain
    # ./configure with no --with-headers lets glibc's build find the
    # kernel UAPI headers at the guest's own real /usr/include (installed
    # there by a prior `unarchive` of linux#headers's own tarball — see
    # native-toolchain.sh) exactly like any ordinary native glibc build.
    (
        if [ -d "$TOOL_DIR/usr/share/bison" ]; then
            export BISON_PKGDATADIR=$TOOL_DIR/usr/share/bison
        fi
        if [ -d "$TOOL_DIR/$target/usr/include" ]; then
            headers=$TOOL_DIR/$target/usr/include
        fi
        require glibc
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
    # losetup/fallocate/mountpoint/mount explicitly enabled: no extra
    # library dependency, cheap either way, and any self-hosting system
    # benefits from having them (not just the CAPS=loop builder guest
    # below).
    #
    # fdisks (sfdisk) is trickier: the guest needs it from its OWN target-
    # built util-linux to partition its own output image (SELF-HOST.md M4 —
    # lib/image.sh's create_partitions(), container-side today via the
    # build-host-native copy build_tools() installs into $TOOL_DIR). But
    # upstream util-linux has no standalone --enable-sfdisk — --enable-
    # fdisks is ONE combined switch for fdisk(8)+sfdisk(8)+cfdisk(8)
    # together (confirmed via ./configure --help: no per-tool cfdisk
    # toggle), and cfdisk hard-requires ncurses/ncursesw/slang or configure
    # itself fails outright — none of those are otherwise part of this
    # minimal target tree. So pull in a small target-built ncursesw
    # (ncurses.sh is already proven, used for TOOL_DIR's own tic/ncurses the
    # same way — see lib/tools.sh) ahead of util-linux, but ONLY for the
    # CAPS=loop builder-guest scenario that actually needs sfdisk — keeping
    # every other build (real Pi hardware images, the plain virt image,
    # busybox-init, …) exactly as lean as before.
    local fdisks=
    case " ${CAPS:-} " in
        *" loop "*)
            fdisks=yes
            ( widec=yes shared=yes normal=yes ada=no debug=no stripping=no require ncurses )
            ;;
    esac
    (
        bindir=/usr/bin sbindir=/usr/sbin libdir=/usr/lib
        chfn_chsh=no login=no nologin=no su=no setpriv=no runuser=no
        pylibmount=no static=no liblastlog2=no python=no systemd=no wall=no
        makeinstall_chown=no makeinstall_setuid=no
        losetup=yes fallocate=yes mountpoint=yes mount=yes fdisks=$fdisks
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
    # TOOL_DIR-relative (same fixup as glibc above; see there, including why
    # this is guarded the same way for the guest).
    (
        if [ -d "$TOOL_DIR/usr/share/bison" ]; then
            export BISON_PKGDATADIR=$TOOL_DIR/usr/share/bison
        fi
        require linux
    )

    # Boot partition files (cmdline.txt + config.txt) — Pi platforms only.
    if [ -n "${DTB:-}" ]; then
        require boot#cmdline
        require boot#config
    fi
}
