# The file systems are made from trees of files, with nothing mounted: the root file system by
# mkfs.btrfs, the Pi layout's boot partition by mtools. On a device they are made on its partitions;
# an image file is put together from them, and gets next to it an SBOM (see lib/sbom.sh) and a
# manifest of the files of each file system. A device gets none: it is no file to take the digest of.
lfs_build_image() {
    [ $# -le 1 ] || bail "Usage: $(basename "$0") image build [IMAGE|DEVICE]"
    local target="${1:-$LFS_IMAGE_DIR/$LFS_PROFILE.img}" shrink=
    local stem="${target%.img}" sbom="${target%.img}.spdx.json"
    [ -d "$system_dir" ] || bail "System tree not found: $system_dir"

    stage image
    if [ -b "$target" ]; then
        # A device is made afresh, like a new image file.
        device=$(realpath "$target")
        confirm_erase
    elif [ -e "$target" ] && [ -e "$sbom" ] && [ -e "$stem.root.txt" ] \
        && lfs_sbom_has_release "$sbom" \
        && [ -z "$(find $system_dir -newer "$target" -print -quit)" ]; then
        echo "image (done)"
        return
    fi
    trap clean_image EXIT
    parts_dir=$(mktemp -dt lfs-XXXXXX)
    stage_root
    if [ -n "${device:-}" ]; then
        create_partitions $device
        find_partitions
    else
        # Made under a name of its own, and moved into place only once complete, so that a failed
        # run never leaves an image behind that looks finished.
        image_file=$target.tmp
        boot_device=$parts_dir/boot.fat
        base_device=$parts_dir/base.btrfs
        # The root file system is as small as its files allow.
        : > $base_device
        shrink=--shrink
    fi
    create_filesystems $shrink
    if [ -n "${image_file:-}" ]; then
        assemble_image
        list_files $root_dir > "$image_file.root.txt"
        if [ "${image_layout:-pi}" != single ]; then
            list_files $system_dir/boot > "$image_file.boot.txt"
        fi
        lfs_sbom_document "${target##*/}" "$(sha256sum < "$image_file" | cut -d' ' -f1)" \
            > "$image_file.spdx.json"
        # The files that the kernel was built from, which the vulnerability scan reads with the SBOM.
        local kernel_files="${target%.img}.kernel-files"
        if [ -f $system_dir/usr/share/lfs/kernel-files ]; then
            cp $system_dir/usr/share/lfs/kernel-files "$kernel_files"
        else
            rm -f "$kernel_files"
        fi
        # The SBOM and the manifests first, as the image tells that all are complete: an image
        # without its SBOM or its root manifest is made anew, and the boot manifest, moved before
        # the root one, is there with it.
        if [ -e "$image_file.boot.txt" ]; then
            mv "$image_file.boot.txt" "$stem.boot.txt"
        fi
        mv "$image_file.root.txt" "$stem.root.txt"
        mv "$image_file.spdx.json" "$sbom"
        mv "$image_file" "$target"
    fi
    clean_image
}

confirm_erase() {
    [ "$(realpath "${LFS_ERASE:-/dev/null}")" = "$device" ] && return 0

    echo "This erases $device:" >&2
    lsblk -o NAME,SIZE,MODEL,FSTYPE,LABEL $device >&2 2>/dev/null || true
    bail "To go ahead, set LFS_ERASE=$device"
}

# The size of the Pi layout's FAT boot partition, in MiB. It holds only the firmware, the kernel and
# the device tree, so it is about as small as FAT32 allows: that needs 65525 clusters, which the
# one-sector clusters that mkfs.fat makes at this size reach at 33 MiB. 35 MiB, after the MiB of the
# partition table, starts the root partition at a multiple of 4 MiB.
readonly boot_size=35

# Where the root file system's partition begins, in MiB: after the MiB that holds the partition
# table, and after the boot partition of the Pi layout. sfdisk aligns partitions to the MiB.
base_start() {
    if [ "${image_layout:-pi}" = single ]; then
        echo 1
    else
        echo $((1 + boot_size))
    fi
}

# Partitions DEVICE, a device or an image file. The root file system's partition takes the rest.
create_partitions() {
    if [ "${image_layout:-pi}" = single ]; then
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
    local name=$(partition_name ${device##*/} $1)
    [ -b /dev/$name ] || mknod /dev/$name b $(tr : ' ' < /sys/class/block/$name/dev)
    echo /dev/$name
}

find_partitions() {
    if [ "${image_layout:-pi}" = single ]; then
        base_device=$(partition_device 1)
    else
        boot_device=$(partition_device 1)
        base_device=$(partition_device 2)
    fi
}

# Makes the file systems on their devices, or in their files, with --shrink to make the root file
# system as small as its files allow. Data and metadata share their chunks (-M): a shrunk file system
# has no room to make chunks in, and what one kind's chunks have free would be lost to the other.
# The root subvolume is read-only where the kernel mounts the root read-only (the `ro` of the boot
# package's command line), so that a remount alone never makes it writable.
create_filesystems() {
    local root_mode=rw cmdline=$system_dir/boot/cmdline.txt
    if [ -f $cmdline ] && tr ' ' '\n' < $cmdline | grep -qx ro; then
        root_mode=ro
    fi
    mkfs.btrfs -f -L base --checksum xxhash -M \
        --rootdir $base_dir --subvol $root_mode:root/$root_volume ${1:-} $base_device
    if [ "${image_layout:-pi}" != single ]; then
        [ -b $boot_device ] || truncate -s ${boot_size}M $boot_device
        mkfs.fat -c -f 1 -F 32 -n BOOT $boot_device
        # FAT has no owners, so the boot files are copied as they are.
        mcopy -s -i $boot_device $system_dir/boot/* ::
    fi
}

# Copies the files of the root file system: the system's, owned by root, the Pi layout's boot files
# aside, as they have a partition of their own; and those that belong to the image.
stage_root() {
    stage "Staging the root file system from $system_dir"
    # The file system's top level, which holds the root subvolume.
    base_dir=$parts_dir/base
    root_dir=$base_dir/root/$root_volume
    mkdir -p $root_dir
    # The system tree belongs to the build user, but the system's files belong to root.
    if [ "${image_layout:-pi}" = single ]; then
        tar -C $system_dir --owner=0 --group=0 --numeric-owner -cf - . | tar -C $root_dir -xpf -
    else
        tar -C $system_dir --owner=0 --group=0 --numeric-owner -cf - --exclude=./boot . \
            | tar -C $root_dir -xpf -
        # Where the boot partition can be mounted.
        mkdir $root_dir/boot
    fi
    # The mode that systemd-tmpfiles gives the root directory at boot (root.conf), which a read-only
    # root could not take then.
    chmod 555 $root_dir
    # The home directory of an account belongs to it.
    local name uid gid home
    while IFS=: read -r name _ uid gid _ home _; do
        case $home in
            /home/*) [ ! -d $root_dir$home ] || chown -R $uid:$gid $root_dir$home ;;
        esac
    done < $root_dir/etc/passwd
    # What the kernel was built from is kept next to the image (lfs_build_image), not in it.
    rm -rf $root_dir/usr/share/lfs
    # Boards without a battery-backed clock start at systemd's build date. systemd never starts the
    # clock earlier than the modification time of this file, so an image boots no earlier than the
    # time it was made. Systems without systemd have no use for it.
    if [ -e $root_dir/usr/lib/systemd/systemd ]; then
        touch $root_dir/usr/lib/clock-epoch
    fi
    # The time zone belongs to the image, so that the system is the same for every zone. A system
    # without tzdata keeps UTC, which needs no zone file.
    local timezone=${LFS_TIMEZONE:-UTC}
    if [ -f $root_dir/usr/share/zoneinfo/$timezone ]; then
        ln -sfn /usr/share/zoneinfo/$timezone $root_dir/etc/localtime
    elif [ -n "${LFS_TIMEZONE:-}" ]; then
        bail "Unknown time zone '$timezone': time zones come with the tzdata package"
    fi
    # With a machine ID, the first boot is an ordinary one. Without it, systemd presets every unit
    # at the first boot, and warns about each unit that a generator made. The ID belongs to the
    # image: cards written from the same image share it. Systems without systemd have no use for it.
    if [ -e $root_dir/usr/lib/systemd/systemd ]; then
        tr -d - < /proc/sys/kernel/random/uuid > $root_dir/etc/machine-id
        chmod 444 $root_dir/etc/machine-id
    fi
    # The release of this project the image is made as: the version of the tree (bin/version), which
    # the Makefile computes, and which tells the images of one release apart. It is in no archive, as
    # archives are shared by every revision.
    local release=${LFS_RELEASE:-local}
    {
        echo "VERSION=\"$release\""
        echo "PRETTY_NAME=\"Linux From Scratch${LFS_RELEASE:+ $LFS_RELEASE}\""
    } >> $root_dir/etc/os-release
    echo "DISTRIB_RELEASE=\"$release\"" >> $root_dir/etc/lsb-release
    if [ -n "${LFS_RELEASE:-}" ]; then
        echo "$LFS_RELEASE" > $root_dir/etc/lfs-release
    fi
}

# Lists the files of the file system made from the tree DIR, as the running system has them: one
# path per line, absolute from the file system's root, in byte order. Directories and links are files
# too.
list_files() {
    (cd $1 && find . ! -name . | sed 's/^\.//' | sort)
}

# Puts the image file together: the partition table, and each file system where its partition is.
assemble_image() {
    local start=$(base_start)
    rm -f "$image_file"
    mkdir -pv "$(dirname "$image_file")"
    truncate -s $((start + ($(wc -c < $base_device) + 1048575) / 1048576))M "$image_file"
    create_partitions "$image_file"
    # The image starts out as zeros, which the file systems' own zeros need not be written over.
    if [ "${image_layout:-pi}" != single ]; then
        dd if=$boot_device of="$image_file" bs=1M seek=1 conv=notrunc,sparse status=none
    fi
    dd if=$base_device of="$image_file" bs=1M seek=$start conv=notrunc,sparse status=none
}

# Removes what making an image leaves behind, the image itself, and its SBOM and manifests, if
# incomplete: at the end of lfs_build_image, and as the EXIT trap it sets, when it fails.
clean_image() {
    [ -z "${parts_dir:-}" ] || rm -rf "$parts_dir"
    [ -z "${image_file:-}" ] \
        || rm -f "$image_file" "$image_file.spdx.json" "$image_file.root.txt" "$image_file.boot.txt"
    unset parts_dir image_file
}
