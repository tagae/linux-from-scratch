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
