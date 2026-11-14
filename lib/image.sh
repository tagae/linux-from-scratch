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

# The file systems are made from trees of files, with nothing mounted: the root file system by
# mkfs.btrfs, the Pi layout's boot partition by mtools. On a device they are made on its partitions;
# an image file is put together from them, and gets an SBOM next to it (see lib/sbom.sh). A device
# gets none: it is no file to take the digest of.
build_image() {
    [ $# -le 1 ] || bail "Usage: $(basename "$0") image build [IMAGE|DEVICE]"
    local target="${1:-$IMAGE_DIR/$PROFILE.img}" shrink=
    local sbom="${target%.img}.spdx.json"
    # One install tree per system key, not a shared $INSTALL_DIR.
    local install_dir=$INSTALL_DIR/$PROFILE
    [ -d "$install_dir" ] || bail "Install directory not found: $install_dir"

    stage image
    if [ -b "$target" ]; then
        # A device is made afresh, like a new image file.
        DEVICE=$(realpath "$target")
        confirm_erase
    elif [ -e "$target" ] && [ -e "$sbom" ] && lfs_sbom_has_release "$sbom" \
        && [ -z "$(find $install_dir -newer "$target" -print -quit)" ]; then
        echo "image (done)"
        return
    fi
    trap clean_image EXIT
    PARTS_DIR=$(mktemp -dt lfs-XXXXXX)
    stage_root
    if [ -n "${DEVICE:-}" ]; then
        create_partitions $DEVICE
        find_partitions
    else
        # Made under a name of its own, and moved into place only once complete, so that a failed
        # run never leaves an image behind that looks finished.
        IMAGE=$target.tmp
        BOOT_DEVICE=$PARTS_DIR/boot.fat
        BASE_DEVICE=$PARTS_DIR/base.btrfs
        if [ -n "${IMAGE_SIZE:-}" ]; then
            # The root file system fills what the partitions ahead of it leave.
            truncate -s $IMAGE_SIZE $BASE_DEVICE
            truncate -s -$(base_start)M $BASE_DEVICE
        else
            # The root file system is as small as its files allow.
            : > $BASE_DEVICE
            shrink=--shrink
        fi
    fi
    create_filesystems $shrink
    if [ -n "${IMAGE:-}" ]; then
        assemble_image
        lfs_sbom_document "${target##*/}" "$(sha256sum < "$IMAGE" | cut -d' ' -f1)" \
            > "$IMAGE.spdx.json"
        # The SBOM first, as the image tells that both are complete: an image without its SBOM
        # is made anew.
        mv "$IMAGE.spdx.json" "$sbom"
        mv "$IMAGE" "$target"
    fi
    clean_image
}

confirm_erase() {
    [ "$(realpath "${ERASE:-/dev/null}")" = "$DEVICE" ] && return 0

    echo "This erases $DEVICE:" >&2
    lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL $DEVICE >&2 2>/dev/null || true
    bail "To go ahead, set ERASE=$DEVICE"
}

# The size of the Pi layout's FAT boot partition, in MiB.
readonly boot_size=128

# Where the root file system's partition begins, in MiB: after the MiB that holds the partition
# table, and after the boot partition of the Pi layout. sfdisk aligns partitions to the MiB.
base_start() {
    if [ "${IMAGE_LAYOUT:-pi}" = single ]; then
        echo 1
    else
        echo $((1 + boot_size))
    fi
}

# Partitions DEVICE, a device or an image file. The root file system's partition takes the rest.
create_partitions() {
    if [ "${IMAGE_LAYOUT:-pi}" = single ]; then
        sfdisk -w always -W always $1 <<- EOF
label: dos
unit: sectors

type=83
EOF
    else
        sfdisk -w always -W always $1 <<- EOF
label: dos
unit: sectors

size=+${boot_size}m, type=c, bootable
type=83
EOF
    fi
    sync
}

# The name of partition NUMBER of a device: the kernel inserts a "p" after device names that end in a
# digit (mmcblk0p1, loop0p1), and none after the others (sdb1, vdb1).
partition_name() {
    case $1 in
        *[0-9]) echo ${1}p$2 ;;
        *) echo $1$2 ;;
    esac
}

# The device of partition NUMBER, which the kernel makes once sfdisk has written the partition
# table. A container's /dev holds only the devices that were there when it started: a node missing
# from it is made after what sysfs says.
partition_device() {
    local name=$(partition_name ${DEVICE##*/} $1)
    [ -b /dev/$name ] || mknod /dev/$name b $(tr : ' ' < /sys/class/block/$name/dev)
    echo /dev/$name
}

find_partitions() {
    if [ "${IMAGE_LAYOUT:-pi}" = single ]; then
        BASE_DEVICE=$(partition_device 1)
    else
        BOOT_DEVICE=$(partition_device 1)
        BASE_DEVICE=$(partition_device 2)
    fi
}

# Makes the file systems on their devices, or in their files, with --shrink to make the root file
# system as small as its files allow. Data and metadata share their chunks (-M): a shrunk file system
# has no room to make chunks in, and what one kind's chunks have free would be lost to the other.
create_filesystems() {
    mkfs.btrfs -f -L base --checksum xxhash -M \
        --rootdir $BASE_DIR --subvol rw:root/$ROOT_VOLUME ${1:-} $BASE_DEVICE
    if [ "${IMAGE_LAYOUT:-pi}" != single ]; then
        [ -b $BOOT_DEVICE ] || truncate -s ${boot_size}M $BOOT_DEVICE
        mkfs.fat -c -f 1 -F 32 -n BOOT $BOOT_DEVICE
        # FAT has no owners, so the boot files are copied as they are.
        mcopy -s -i $BOOT_DEVICE $INSTALL_DIR/$PROFILE/boot/* ::
    fi
}

# Copies the files of the root file system: the system's, owned by root, the Pi layout's boot files
# aside, as they have a partition of their own; and those that belong to the image.
stage_root() {
    local install_dir=$INSTALL_DIR/$PROFILE
    stage "Staging the root file system from $install_dir"
    # The file system's top level, which holds the root subvolume.
    BASE_DIR=$PARTS_DIR/base
    ROOT_DIR=$BASE_DIR/root/$ROOT_VOLUME
    mkdir -p $ROOT_DIR
    # The install tree belongs to the build user, but the system's files belong to root.
    if [ "${IMAGE_LAYOUT:-pi}" = single ]; then
        tar -C $install_dir --owner=0 --group=0 --numeric-owner -cf - . | tar -C $ROOT_DIR -xpf -
    else
        tar -C $install_dir --owner=0 --group=0 --numeric-owner -cf - --exclude=./boot . \
            | tar -C $ROOT_DIR -xpf -
        # Where the boot partition is mounted.
        mkdir $ROOT_DIR/boot
    fi
    # Boards without a battery-backed clock start at systemd's build date. systemd and timesyncd
    # never start the clock earlier than the modification time of this file, so an image boots no
    # earlier than the time it was made.
    mkdir -p $ROOT_DIR/var/lib/systemd/timesync
    touch $ROOT_DIR/var/lib/systemd/timesync/clock
    # The time zone belongs to the image, so that the system is the same for every zone. A system
    # without tzdata keeps UTC, which needs no zone file.
    local timezone=${TIMEZONE:-UTC}
    if [ -f $ROOT_DIR/usr/share/zoneinfo/$timezone ]; then
        ln -sfn /usr/share/zoneinfo/$timezone $ROOT_DIR/etc/localtime
    elif [ -n "${TIMEZONE:-}" ]; then
        bail "Unknown time zone '$timezone': time zones come with the tzdata package"
    fi
    # With a machine ID, the first boot is an ordinary one. Without it, systemd presets every unit
    # at the first boot, and warns about each unit that a generator made. The ID belongs to the
    # image: cards written from the same image share it.
    tr -d - < /proc/sys/kernel/random/uuid > $ROOT_DIR/etc/machine-id
    chmod 444 $ROOT_DIR/etc/machine-id
    # The release of this project the image is made as: the version of the tree (bin/version), which
    # the Makefile computes, and which tells the images of one release apart. It is in no archive, as
    # archives are shared by every revision.
    local release=${LFS_RELEASE:-local}
    {
        echo "VERSION=\"$release\""
        echo "PRETTY_NAME=\"Linux From Scratch${LFS_RELEASE:+ $LFS_RELEASE}\""
    } >> $ROOT_DIR/etc/os-release
    echo "DISTRIB_RELEASE=\"$release\"" >> $ROOT_DIR/etc/lsb-release
    if [ -n "${LFS_RELEASE:-}" ]; then
        echo "$LFS_RELEASE" > $ROOT_DIR/etc/lfs-release
    fi
}

# Puts the image file together: the partition table, and each file system where its partition is.
assemble_image() {
    local start=$(base_start)
    rm -f "$IMAGE"
    mkdir -pv "$(dirname "$IMAGE")"
    truncate -s $((start + ($(wc -c < $BASE_DEVICE) + 1048575) / 1048576))M "$IMAGE"
    create_partitions "$IMAGE"
    # The image starts out as zeros, which the file systems' own zeros need not be written over.
    if [ "${IMAGE_LAYOUT:-pi}" != single ]; then
        dd if=$BOOT_DEVICE of="$IMAGE" bs=1M seek=1 conv=notrunc,sparse status=none
    fi
    dd if=$BASE_DEVICE of="$IMAGE" bs=1M seek=$start conv=notrunc,sparse status=none
}

# Removes what making an image leaves behind, the image itself, and its SBOM, if incomplete: at the
# end of build_image, and as the EXIT trap it sets, when it fails.
clean_image() {
    [ -z "${PARTS_DIR:-}" ] || rm -rf "$PARTS_DIR"
    [ -z "${IMAGE:-}" ] || rm -f "$IMAGE" "$IMAGE.spdx.json"
    unset PARTS_DIR IMAGE
}
