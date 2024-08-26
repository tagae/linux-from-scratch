image() {
    readonly IMAGE
    readonly ROOT_VOLUME=$(date +%Y-%m-%d-%H-%M-%S)
    stage image
    create_image
    attach_image
    device
}

create_image() {
    [ -z "$IMAGE" ] && return
    [ -f "$IMAGE" ] && return
    mkdir -pv "$(dirname $IMAGE)"
    fallocate -l "${IMAGE_SIZE:-4g}" "$IMAGE"
}

attach_image() {
    [ -z "$IMAGE" ] && return
    DEVICE=$(losetup -f)
    losetup -fP "$IMAGE"
}

detach_image() {
    if [ -b "${DEVICE:-}" ]; then
        losetup -d $DEVICE
        kpartx -dv $DEVICE
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
    sfdisk -f -w always -W always $DEVICE <<- EOF
label: dos
unit: sectors

size=+128m, type=c, bootable
type=83
EOF
    sync
    find_partitions
}

find_partitions() {
    kpartx -av $DEVICE
    BOOT_DEVICE=/dev/mapper/${DEVICE##*/}p1
    BASE_DEVICE=/dev/mapper/${DEVICE##*/}p2
    [ -b $BOOT_DEVICE ] && [ -b $BASE_DEVICE ]
}

create_filesystems() {
    mkfs.btrfs -f -L base --checksum xxhash $BASE_DEVICE
    mkfs.fat -c -f 1 -F 32 -n BOOT $BOOT_DEVICE
}

mount_partitions() {
    BASE_DIR=$(mktemp -dt lfs-XXXXXX)
    mount -v $BASE_DEVICE $BASE_DIR
    mkdir -p $BASE_DIR/system
    ROOT_DIR=$BASE_DIR/system/$ROOT_VOLUME
    btrfs subvolume create $ROOT_DIR

    BOOT_DIR=$ROOT_DIR/boot
    mkdir -p $BOOT_DIR
    mount -v $BOOT_DEVICE $BOOT_DIR
}

unmount_partitions() {
    if [ -n "${BASE_DIR:-}" ]; then
        if [ -d $BOOT_DIR ] && mountpoint -q $BOOT_DIR; then
            umount -v $BOOT_DIR
        fi
        if [ -d $BASE_DIR ] && mountpoint -q $BASE_DIR; then
            umount -v $BASE_DIR
        fi
    fi
}
