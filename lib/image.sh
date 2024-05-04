image() {
    readonly MEDIA=$1
    readonly ROOT_VOLUME=$(date +%Y-%m-%d-%H-%M-%S)

    trap cleanup EXIT

    stage Prepare media
    create_media
    attach_media

    stage Prepare filesystems
    find_partitions || create_partitions
    create_filesystems
    mount_partitions

    echo Created image $MEDIA
}

create_media() {
    [ -z "$MEDIA" ] && return
    [ -f "$MEDIA" ] && return
    fallocate -l "${MEDIA_SIZE:-4g}" "$MEDIA"
}

attach_media() {
    [ -z "$MEDIA" ] && return
    DEVICE=$(sudo losetup -f)
    sudo losetup -fP "$MEDIA"
}

detach_media() {
    if [ -b "${DEVICE:-}" ]; then
        sudo losetup -d $DEVICE
        sudo kpartx -dv $DEVICE
    fi
}

create_partitions() {
    sudo sfdisk -f -w always -W always $DEVICE <<- EOF
label: dos
unit: sectors

size=+128m, type=c, bootable
type=83
EOF
    sync
    find_partitions
}

find_partitions() {
    sudo kpartx -av $DEVICE
    BOOT_DEVICE=/dev/mapper/${DEVICE##*/}p1
    BASE_DEVICE=/dev/mapper/${DEVICE##*/}p2
    [ -b $BOOT_DEVICE ] && [ -b $BASE_DEVICE ]
}

create_filesystems() {
    sudo mkfs.btrfs -f -L base --checksum xxhash $BASE_DEVICE
    sudo mkfs.fat -c -f 1 -F 32 -n boot $BOOT_DEVICE
}

mount_partitions() {
    BASE_DIR=$(mktemp -dt lfs-XXXXXX)
    sudo mount -v $BASE_DEVICE $BASE_DIR
    sudo mkdir -p $BASE_DIR/system
    SYSROOT=$BASE_DIR/system/$ROOT_VOLUME
    sudo btrfs subvolume create $SYSROOT

    BOOT_DIR=$SYSROOT/boot
    sudo mkdir -p $BOOT_DIR
    sudo mount -v $BOOT_DEVICE $BOOT_DIR
}

unmount_partitions() {
    if [ -n "${BASE_DIR:-}" ]; then
        if [ -d $BOOT_DIR ] && mountpoint $BOOT_DIR; then
            sudo umount -v $BOOT_DIR
        fi
        if [ -d $BASE_DIR ] && mountpoint $BASE_DIR; then
            sudo umount -v $BASE_DIR
        fi
    fi
}

cleanup() {
    stage Cleanup
    unmount_partitions
    detach_media
}
