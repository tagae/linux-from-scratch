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
    [ $# -le 1 ] || bail "Usage: $(basename "$0") image build [IMAGE|DEVICE]"
    local target="${1:-$IMAGE_DIR/$SYSTEM_KEY.img}"

    # libmount needs a writable /run/mount for its own lock/state files —
    # this is a bare `FROM scratch` image with no /run at all, and without
    # it mount(8) fails with a misleading "must be superuser" message
    # (confirmed the raw mount(2) syscall itself succeeds fine otherwise).
    mkdir -p /run/mount

    stage image
    if [ -b "$target" ]; then
        # A device is made afresh, like a new image file.
        DEVICE=$(realpath "$target")
        confirm_erase
    else
        IMAGE=$target
        if [ -e "$IMAGE" ] && [ -d "$INSTALL_DIR/$SYSTEM_KEY" ] \
            && [ -z "$(find $INSTALL_DIR/$SYSTEM_KEY -newer "$IMAGE" -print -quit)" ]; then
            echo "image (done)"
            return
        fi
        create_image
        attach_image
    fi
    create_partitions
    create_filesystems
    mount_partitions
    populate_image
    unmount_all
}

create_image() {
    rm -f "$IMAGE"
    mkdir -pv "$(dirname $IMAGE)"
    fallocate -l "${IMAGE_SIZE:-1g}" "$IMAGE"
}

attach_image() {
    DEVICE=$(losetup -f)
    losetup -fP "$IMAGE"
}

detach_image() {
    if [ -b "${DEVICE:-}" ]; then
        # Only the loop device made for an image is ours to detach.
        [ -z "${IMAGE:-}" ] || losetup -d $DEVICE 2>/dev/null || true
        kpartx -dv $DEVICE 2>/dev/null || true
    fi
}

confirm_erase() {
    [ "$(realpath "${ERASE:-/dev/null}")" = "$DEVICE" ] && return 0

    echo "This erases $DEVICE:" >&2
    lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL $DEVICE >&2 2>/dev/null || true
    bail "To go ahead, set ERASE=$DEVICE"
}

create_partitions() {
    if [ "${IMAGE_LAYOUT:-pi}" = single ]; then
        sfdisk -w always -W always $DEVICE <<- EOF
label: dos
unit: sectors

type=83
EOF
    else
        sfdisk -w always -W always $DEVICE <<- EOF
label: dos
unit: sectors

size=+128m, type=c, bootable
type=83
EOF
    fi
    sync
    find_partitions
}

# The name of partition NUMBER of a device: the kernel inserts a "p" after device names that end in a
# digit (mmcblk0p1, loop0p1), and none after the others (sdb1, vdb1).
partition_name() {
    case $1 in
        *[0-9]) echo ${1}p$2 ;;
        *) echo $1$2 ;;
    esac
}

find_partitions() {
    local dir=/dev
    if command -v kpartx >/dev/null 2>&1; then
        kpartx -av $DEVICE
        dir=/dev/mapper
    fi
    local name=${DEVICE##*/}
    if [ "${IMAGE_LAYOUT:-pi}" = single ]; then
        BASE_DEVICE=$dir/$(partition_name $name 1)
        [ -b $BASE_DEVICE ]
    else
        BOOT_DEVICE=$dir/$(partition_name $name 1)
        BASE_DEVICE=$dir/$(partition_name $name 2)
        [ -b $BOOT_DEVICE ] && [ -b $BASE_DEVICE ]
    fi
}

create_filesystems() {
    mkfs.btrfs -f -L base --checksum xxhash $BASE_DEVICE
    [ "${IMAGE_LAYOUT:-pi}" = single ] || mkfs.fat -c -f 1 -F 32 -n BOOT $BOOT_DEVICE
}

mount_partitions() {
    BASE_DIR=$(mktemp -dt lfs-XXXXXX)
    mount -v $BASE_DEVICE $BASE_DIR
    mkdir -p $BASE_DIR/root
    ROOT_DIR=$BASE_DIR/root/$ROOT_VOLUME
    btrfs subvolume create $ROOT_DIR

    BOOT_DIR=$ROOT_DIR/boot
    mkdir -p $BOOT_DIR
    [ "${IMAGE_LAYOUT:-pi}" = single ] || mount -v $BOOT_DEVICE $BOOT_DIR
}

populate_image() {
    [ -n "${ROOT_DIR:-}" ] || bail "No root directory — call 'image' first"
    # One install tree per system key, not a shared $INSTALL_DIR.
    local platform_install_dir=$INSTALL_DIR/$SYSTEM_KEY
    [ -d "$platform_install_dir" ] || bail "Install directory not found: $platform_install_dir"
    stage "Populating image from $platform_install_dir"
    # The install tree belongs to the build user, but the system's files belong to root.
    if [ "${IMAGE_LAYOUT:-pi}" = single ]; then
        # All files including boot go into the btrfs subvolume
        tar -C $platform_install_dir --owner=0 --group=0 --numeric-owner -cf - . \
            | tar -C $ROOT_DIR -xpf -
    else
        # Rootfs to btrfs subvolume (exclude boot — it lives on the FAT partition)
        tar -C $platform_install_dir --owner=0 --group=0 --numeric-owner -cf - --exclude=./boot . \
            | tar -C $ROOT_DIR -xpf -
        # Boot files to FAT partition (ownership not supported by FAT)
        cp -r $platform_install_dir/boot/. $ROOT_DIR/boot/
    fi
    # Boards without a battery-backed clock start at systemd's build date. systemd and timesyncd
    # never start the clock earlier than the modification time of this file, so an image boots no
    # earlier than the time it was made.
    mkdir -p $ROOT_DIR/var/lib/systemd/timesync
    touch $ROOT_DIR/var/lib/systemd/timesync/clock
    # With a machine ID, the first boot is an ordinary one. Without it, systemd presets every unit
    # at the first boot, and warns about each unit that a generator made. The ID belongs to the
    # image: cards written from the same image share it.
    tr -d - < /proc/sys/kernel/random/uuid > $ROOT_DIR/etc/machine-id
    chmod 444 $ROOT_DIR/etc/machine-id
}

unmount_partitions() {
    if [ -n "${BASE_DIR:-}" ]; then
        if [ -d "${BOOT_DIR:-}" ] && mountpoint -q "$BOOT_DIR" 2>/dev/null; then
            umount -v $BOOT_DIR
        fi
        if [ -d "$BASE_DIR" ] && mountpoint -q "$BASE_DIR" 2>/dev/null; then
            umount -v $BASE_DIR
        fi
    fi
}

# The one cleanup chain: called explicitly at the end of build_image, and
# as lfs's EXIT trap (where the unset is harmless and the guards above
# make every step a no-op if nothing is mounted/attached).
unmount_all() {
    unmount_partitions
    detach_image
    unset BASE_DIR ROOT_DIR BOOT_DIR IMAGE DEVICE BOOT_DEVICE BASE_DEVICE
}
