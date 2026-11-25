# Boot the built system's image in QEMU.

qemu() {
    [ $# -le 1 ] || usage "qemu [IMAGE]"
    local image="${1:-$LFS_IMAGE_DIR/$LFS_PROFILE.img}"
    local kernel="$LFS_WORK_DIR/boot/$LFS_PROFILE/kernel.img"
    local cmdline="$LFS_WORK_DIR/boot/$LFS_PROFILE/cmdline.txt"
    [ -f "$kernel" ] || bail "Kernel not found: $kernel"
    [ -f "$image" ] || bail "Image not found: $image"
    set -- -kernel "$kernel"
    if [ -n "${dev_tree_blob:-}" ]; then
        local dtb="$LFS_WORK_DIR/boot/$LFS_PROFILE/${dev_tree_blob##*/}"
        [ -f "$dtb" ] || bail "DTB not found: $dtb"
        set -- "$@" -dtb "$dtb"
    fi
    # The system boots from an overlay of the image, which takes what the system writes, so that the
    # image stays as it was made, to be written to a card. The overlay lasts until the image is made
    # anew. Its size is a power of two, the only sizes of SD card that QEMU takes.
    local overlay=${image%.img}.qcow2
    if ! [ "$overlay" -nt "$image" ]; then
        local needed=$(( ($(wc -c < "$image") + 1048575) / 1048576 )) size=1
        while [ $size -lt $needed ]; do
            size=$((size * 2))
        done
        qemu-img create -q -f qcow2 -b "${image##*/}" -F raw "$overlay" ${size}M
    fi
    # A system that has a kernel command line of its own (the boot package's) boots with it, and
    # with what only QEMU needs; the others with the platform's and the subvolume that images boot.
    local append
    if [ -f "$cmdline" ]; then
        append="$(cat "$cmdline") ${qemu_append:-}"
    else
        append="${qemu_append:-} rootfstype=btrfs rootflags=subvol=root/$root_volume rw rootwait"
    fi
    exec ${qemu_system:-qemu-system-$target_arch} -nodefaults -no-user-config ${qemu_flags:-} \
        "$@" \
        -append "$append" \
        -drive "file=$overlay,format=qcow2,if=${qemu_disk_if:-sd}" \
        ${LFS_QEMU_EXTRA:-}
}
