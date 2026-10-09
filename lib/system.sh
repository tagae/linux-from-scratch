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
    target_build_env

    install bootable-$USERLAND

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
