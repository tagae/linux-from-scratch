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
    # Guest phase (LFS_PHASE=guest, SELF-HOST.md M4): install() would
    # otherwise apply guest_build_env instead (see there) — host left
    # UNSET (a bare native build) and package_merge_dir=/ (installs
    # straight into the LIVE system), right for `./lfs install <pkg>`
    # one-offs but wrong for a whole `system build`: that wants its own
    # guest-local staging tree, not to clobber the booted system out from
    # under itself mid-build. Calling target_build_env here FIRST — its
    # `:=` defaults, so install()'s own guest_build_env call further down
    # becomes a no-op for prefix/package_variant/package_merge_dir — sets
    # host=$target too, which on the guest resolves to the native
    # $target-prefixed toolchain (the same names host==target-built by
    # package/native-toolchain.sh, see gcc.sh) rather than leaving host
    # unset; either way every package genuinely builds native (build=host
    # on the guest either way), this just also fixes package_merge_dir to
    # $INSTALL_DIR/$SYSTEM_KEY (a separate guest-local tree — see lfs's
    # guest-phase INSTALL_DIR default) instead of "/".
    [ "${LFS_PHASE:-}" = guest ] && target_build_env

    # The package set that makes up a bootable system lives in an umbrella
    # package — bootable-$INIT (bootable-systemd, bootable-busybox), which
    # depends on its members and sets each one's build knobs. install()
    # establishes the target build environment (host=$target,
    # package_install_dir=$INSTALL_DIR/$SYSTEM_KEY, package_variant=
    # $SYSTEM_KEY, …) — see target_build_env in lib/package.sh. Everything
    # below is the non-package residue: staging the kernel where the
    # host-side `qemu` can read it.
    install bootable-$INIT

    # `./lfs qemu` runs directly on the host, not in a container — INSTALL_DIR
    # is a Docker volume the host can't see at all. WORK_DIR/boot is bind-
    # mounted to the host (see docker-compose.yaml) specifically so the
    # kernel (and DTB, for Pi platforms tested under QEMU) end up somewhere
    # the host-side `qemu` command can actually read. Scoped under
    # WORK_DIR/boot/$SYSTEM_KEY (platform + init flavor), not flat: this
    # copy is unconditional on every system build (unlike the packages
    # above, it's not gated by an install stamp), so a shared path meant
    # one build's kernel/DTB silently clobbered another's.
    mkdir -p $WORK_DIR/boot/$SYSTEM_KEY
    cp -v $INSTALL_DIR/$SYSTEM_KEY/boot/kernel.img $WORK_DIR/boot/$SYSTEM_KEY/
    if [ -n "${DTB:-}" ]; then
        mkdir -p $WORK_DIR/boot/$SYSTEM_KEY/$(dirname $DTB)
        cp -v $INSTALL_DIR/$SYSTEM_KEY/boot/$DTB $WORK_DIR/boot/$SYSTEM_KEY/$DTB
    fi
}
