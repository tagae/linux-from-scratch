# Boot the built system's image in QEMU.

qemu() {
    [ $# -le 1 ] || usage "qemu [IMAGE]"
    IMAGE="${1:-$IMAGE_DIR/$SYSTEM_KEY.img}"
    local kernel="$WORK_DIR/boot/$SYSTEM_KEY/kernel.img"
    [ -f "$kernel" ] || bail "Kernel not found: $kernel"
    [ -f "$IMAGE" ] || bail "Image not found: $IMAGE"
    set -- -kernel "$kernel"
    if [ -n "${dev_tree_blob:-}" ]; then
        local dtb="$WORK_DIR/boot/$SYSTEM_KEY/${dev_tree_blob##*/}"
        [ -f "$dtb" ] || bail "DTB not found: $dtb"
        set -- "$@" -dtb "$dtb"
    fi
    # The system boots from an overlay of the image, which takes what the system writes, so that the
    # image stays as it was made, to be written to a card. The overlay lasts until the image is made
    # anew. Its size is a power of two, the only sizes of SD card that QEMU takes.
    local overlay=${IMAGE%.img}.qcow2
    if ! [ "$overlay" -nt "$IMAGE" ]; then
        local needed=$(( ($(wc -c < "$IMAGE") + 1048575) / 1048576 )) size=1
        while [ $size -lt $needed ]; do
            size=$((size * 2))
        done
        qemu-img create -q -f qcow2 -b "${IMAGE##*/}" -F raw "$overlay" ${size}M
    fi
    exec ${QEMU:-qemu-system-$target_arch} -nodefaults -no-user-config ${QEMU_FLAGS:-} \
        -no-reboot \
        "$@" \
        -append "${QEMU_APPEND:-} \
        ${ROOTFLAGS:-rootfstype=btrfs rootflags=subvol=root/$ROOT_VOLUME rw rootwait}" \
        -drive "file=$overlay,format=qcow2,if=${QEMU_DISK_IF:-sd}" \
        ${QEMU_EXTRA:-}
}
