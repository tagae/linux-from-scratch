# Boot the built system's image in QEMU.

qemu() {
    [ $# -le 1 ] || usage "qemu [IMAGE]"
    IMAGE="${1:-$IMAGE_DIR/$SYSTEM_KEY.img}"
    local kernel="$WORK_DIR/boot/$SYSTEM_KEY/kernel.img"
    [ -f "$kernel" ] || bail "Kernel not found: $kernel"
    set -- -kernel "$kernel"
    if [ -n "${dev_tree_blob:-}" ]; then
        local dtb="$WORK_DIR/boot/$SYSTEM_KEY/${dev_tree_blob##*/}"
        [ -f "$dtb" ] || bail "DTB not found: $dtb"
        set -- "$@" -dtb "$dtb"
    fi
    exec ${QEMU:-qemu-system-$target_arch} -nodefaults -no-user-config ${QEMU_FLAGS:-} \
        -no-reboot \
        "$@" \
        -append "${QEMU_APPEND:-} \
        ${ROOTFLAGS:-rootfstype=btrfs rootflags=subvol=root/$ROOT_VOLUME rw rootwait}" \
        -drive "file=$IMAGE,format=raw,if=${QEMU_DISK_IF:-sd}" \
        ${QEMU_EXTRA:-}
}
