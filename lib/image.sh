image() {
    case "${1:-help}" in
        build)
            shift
            build_image "$@"
            ;;
        help)
            echo "Usage: $(basename "$0") image <subcommand>"
            if [ $# -eq 1 ]; then exit 0; else exit 1; fi
            ;;
        *) bail "Unknown command '$1'" ;;
    esac
}

build_image() {
    [ $# -le 1 ] || bail "Usage: $(basename "$0") image build [IMAGE]"
    readonly IMAGE="${1:-$IMAGE_DIR/$PLATFORM.img}"
    stage image
    create_image
    attach_image
    device
    populate_image
}

create_image() {
    [ -z "$IMAGE" ] && return
    rm -f "$IMAGE"
    mkdir -pv "$(dirname $IMAGE)"
    sudo fallocate -l "${IMAGE_SIZE:-4g}" "$IMAGE"
}

attach_image() {
    [ -z "$IMAGE" ] && return
    DEVICE=$(sudo losetup -f)
    sudo losetup -fP "$IMAGE"
}

detach_image() {
    if [ -b "${DEVICE:-}" ]; then
        sudo losetup -d $DEVICE 2>/dev/null || true
        sudo kpartx -dv $DEVICE 2>/dev/null || true
    fi
}

device() {
    stage device
    find_partitions || {
        create_partitions
        create_filesystems
    }
    mount_partitions
}

create_partitions() {
    if [ "${IMAGE_LAYOUT:-pi}" = single ]; then
        sudo sfdisk -f -w always -W always $DEVICE <<- EOF
label: dos
unit: sectors

type=83
EOF
    else
        sudo sfdisk -f -w always -W always $DEVICE <<- EOF
label: dos
unit: sectors

size=+128m, type=c, bootable
type=83
EOF
    fi
    sync
    find_partitions
}

find_partitions() {
    sudo kpartx -av $DEVICE
    if [ "${IMAGE_LAYOUT:-pi}" = single ]; then
        BASE_DEVICE=/dev/mapper/${DEVICE##*/}p1
        [ -b $BASE_DEVICE ]
    else
        BOOT_DEVICE=/dev/mapper/${DEVICE##*/}p1
        BASE_DEVICE=/dev/mapper/${DEVICE##*/}p2
        [ -b $BOOT_DEVICE ] && [ -b $BASE_DEVICE ]
    fi
}

create_filesystems() {
    sudo mkfs.btrfs -f -L base --checksum xxhash $BASE_DEVICE
    [ "${IMAGE_LAYOUT:-pi}" = single ] || sudo mkfs.fat -c -f 1 -F 32 -n BOOT $BOOT_DEVICE
}

mount_partitions() {
    BASE_DIR=$(mktemp -dt lfs-XXXXXX)
    sudo mount -v $BASE_DEVICE $BASE_DIR
    sudo mkdir -p $BASE_DIR/root
    ROOT_DIR=$BASE_DIR/root/$ROOT_VOLUME
    sudo btrfs subvolume create $ROOT_DIR

    BOOT_DIR=$ROOT_DIR/boot
    sudo mkdir -p $BOOT_DIR
    [ "${IMAGE_LAYOUT:-pi}" = single ] || sudo mount -v $BOOT_DEVICE $BOOT_DIR
}

populate_image() {
    [ -n "${ROOT_DIR:-}" ] || bail "No root directory — call 'image' first"
    [ -d "$INSTALL_DIR" ] || bail "Install directory not found: $INSTALL_DIR — run './lfs system' first"
    stage "Populating image from $INSTALL_DIR"
    if [ "${IMAGE_LAYOUT:-pi}" = single ]; then
        # All files including boot go into the btrfs subvolume
        sudo tar -C $INSTALL_DIR -cf - . | sudo tar -C $ROOT_DIR -xf -
    else
        # Rootfs to btrfs subvolume (exclude boot — it lives on the FAT partition)
        sudo tar -C $INSTALL_DIR -cf - --exclude=./boot . | sudo tar -C $ROOT_DIR -xf -
        # Boot files to FAT partition (ownership not supported by FAT)
        sudo cp -r $INSTALL_DIR/boot/. $ROOT_DIR/boot/
    fi
}

unmount_all() {
    if [ -n "${BASE_DIR:-}" ]; then
        if [ -d "${BOOT_DIR:-}" ] && mountpoint -q "$BOOT_DIR" 2>/dev/null; then
            sudo umount -v $BOOT_DIR
        fi
        if [ -d "$BASE_DIR" ] && mountpoint -q "$BASE_DIR" 2>/dev/null; then
            sudo umount -v $BASE_DIR
        fi
    fi
    detach_image
    unset BASE_DIR ROOT_DIR BOOT_DIR DEVICE BOOT_DEVICE BASE_DEVICE
}

unmount_partitions() {
    if [ -n "${BASE_DIR:-}" ]; then
        if [ -d "${BOOT_DIR:-}" ] && mountpoint -q "$BOOT_DIR" 2>/dev/null; then
            sudo umount -v $BOOT_DIR
        fi
        if [ -d "$BASE_DIR" ] && mountpoint -q "$BASE_DIR" 2>/dev/null; then
            sudo umount -v $BASE_DIR
        fi
    fi
}

image_cleanup() {
    unmount_partitions
    detach_image
}
