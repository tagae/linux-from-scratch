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
    readonly IMAGE="${1:-$IMAGE_DIR/$SYSTEM_KEY.img}"

    # Mirrors the _once-stamp pattern lib/package.sh uses everywhere else:
    # skip the (expensive — mkfs/tar/mount) rebuild if $IMAGE already
    # reflects the current $INSTALL_DIR/$SYSTEM_KEY content. This can't live
    # in the Makefile instead: image/%.img's prerequisite is the phony
    # system-%, not $INSTALL_DIR itself, since $INSTALL_DIR is a Docker
    # volume invisible to the host-side `make` process — so image/%.img's
    # recipe always gets invoked, and the skip has to happen in here.
    if [ -e "$IMAGE" ] && [ -d "$INSTALL_DIR/$SYSTEM_KEY" ] \
        && [ -z "$(find $INSTALL_DIR/$SYSTEM_KEY -newer "$IMAGE" -print -quit)" ]; then
        echo "image (done)"
        return
    fi

    # libmount needs a writable /run/mount for its own lock/state files —
    # this is a bare `FROM scratch` image with no /run at all, and without
    # it mount(8) fails with a misleading "must be superuser" message
    # (confirmed the raw mount(2) syscall itself succeeds fine otherwise).
    mkdir -p /run/mount

    stage image
    create_image
    attach_image
    device
    populate_image
    unmount_all
}

create_image() {
    [ -z "$IMAGE" ] && return
    rm -f "$IMAGE"
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
        losetup -d $DEVICE 2>/dev/null || true
        kpartx -dv $DEVICE 2>/dev/null || true
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
        sfdisk -f -w always -W always $DEVICE <<- EOF
label: dos
unit: sectors

type=83
EOF
    else
        sfdisk -f -w always -W always $DEVICE <<- EOF
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
    if command -v kpartx >/dev/null 2>&1; then
        # losetup -P's own kernel-level partition scanning doesn't reliably
        # create /dev/loopNpM device nodes inside a container (no working
        # udev/devtmpfs auto-population there) — confirmed empirically, not
        # just in theory. kpartx creates the same devices explicitly via
        # device-mapper instead, which doesn't have that problem.
        kpartx -av $DEVICE
        if [ "${IMAGE_LAYOUT:-pi}" = single ]; then
            BASE_DEVICE=/dev/mapper/${DEVICE##*/}p1
            [ -b $BASE_DEVICE ]
        else
            BOOT_DEVICE=/dev/mapper/${DEVICE##*/}p1
            BASE_DEVICE=/dev/mapper/${DEVICE##*/}p2
            [ -b $BOOT_DEVICE ] && [ -b $BASE_DEVICE ]
        fi
    else
        # Guest phase fallback: kpartx is container-only build-time tooling,
        # absent on the guest. But
        # the container-only problem above doesn't apply
        # here — the guest boots a real kernel with a real, working
        # devtmpfs (CONFIG_DEVTMPFS_MOUNT=y, see package/linux/base.config),
        # so losetup -P's own kernel-level partition scanning (attach_image,
        # already unconditional) DOES reliably create /dev/loopNpM nodes on
        # its own, with nothing further to do here beyond checking for them
        # under their plain kernel-assigned names (no device-mapper
        # involved at all).
        if [ "${IMAGE_LAYOUT:-pi}" = single ]; then
            BASE_DEVICE=${DEVICE}p1
            [ -b $BASE_DEVICE ]
        else
            BOOT_DEVICE=${DEVICE}p1
            BASE_DEVICE=${DEVICE}p2
            [ -b $BOOT_DEVICE ] && [ -b $BASE_DEVICE ]
        fi
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
    unset BASE_DIR ROOT_DIR BOOT_DIR DEVICE BOOT_DEVICE BASE_DEVICE
}
