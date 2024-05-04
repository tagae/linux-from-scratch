image() {
    readonly MEDIA=$1
    readonly ROOT_VOLUME=$(date +%Y-%m-%d-%H-%M-%S)

    trap cleanup EXIT

    set -x
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
    mkdir -p "$(dirname $MEDIA)"
    fallocate -l "${MEDIA_SIZE:-4g}" "$MEDIA"
}

attach_media() {
    [ -z "$MEDIA" ] && return
    DEVICE=$(losetup -f)
    losetup -fP "$MEDIA"
}

detach_media() {
    if [ -b "${DEVICE:-}" ]; then
        losetup -d $DEVICE
        kpartx -dv $DEVICE
    fi
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
    mkfs.fat -c -f 1 -F 32 -n boot $BOOT_DEVICE
}

mount_partitions() {
    BASE_DIR=$(mktemp -dt lfs-XXXXXX)
    mount -v $BASE_DEVICE $BASE_DIR
    mkdir -p $BASE_DIR/system
    SYSROOT=$BASE_DIR/system/$ROOT_VOLUME
    btrfs subvolume create $SYSROOT

    BOOT_DIR=$SYSROOT/boot
    mkdir -p $BOOT_DIR
    mount -v $BOOT_DEVICE $BOOT_DIR
}

unmount_partitions() {
    if [ -n "${BASE_DIR:-}" ]; then
        if [ -d $BOOT_DIR ] && mountpoint $BOOT_DIR; then
            umount -v $BOOT_DIR
        fi
        if [ -d $BASE_DIR ] && mountpoint $BASE_DIR; then
            umount -v $BASE_DIR
        fi
    fi
}

cleanup() {
    stage Cleanup
    unmount_partitions
    detach_media
}
