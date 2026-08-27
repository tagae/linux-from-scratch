# Boot the built system's image in QEMU.

qemu() {
    [ $# -le 1 ] || usage "qemu [IMAGE]"}
    IMAGE="${1:-$IMAGE_DIR/$SYSTEM_KEY.img}"
    local kernel="$WORK_DIR/boot/$SYSTEM_KEY/kernel.img"
    [ -f "$kernel" ] || bail "Kernel not found: $kernel (run './lfs system build' first)"
    set -- -kernel "$kernel"
    if [ -n "${DTB:-}" ]; then
        local dtb="$WORK_DIR/boot/$SYSTEM_KEY/$DTB"
        [ -f "$dtb" ] || bail "DTB not found: $dtb (run './lfs system build' first)"
        set -- "$@" -dtb "$dtb"
    fi
    if has_cap network; then
        set -- "$@" -netdev user,id=net0 -device virtio-net-pci,netdev=net0
    fi
    if has_cap 9p; then
        set -- "$@" \
            -fsdev local,id=lfs,path=$PROJECT_DIR,security_model=mapped-xattr \
            -device virtio-9p-pci,fsdev=lfs,mount_tag=lfs
    fi
    if has_cap usb && [ -n "${USB_DISK:-}" ]; then
        [ -f "$USB_DISK" ] || bail "USB_DISK not found: $USB_DISK"
        set -- "$@" \
            -drive if=none,id=usbstick,format=raw,file=$USB_DISK,cache=writethrough
        case $PLATFORM in
            pi0)
                set -- "$@" -device usb-storage,bus=usb-bus.0,drive=usbstick
                ;;
            *)
                set -- "$@" \
                    -device qemu-xhci,id=xhci \
                    -device usb-storage,bus=xhci.0,drive=usbstick
                ;;
        esac
    fi
    if has_cap amnesia; then
        : ${ROOTFLAGS:=rootfstype=btrfs rootflags=subvol=root/$ROOT_VOLUME,rescue=nologreplay ro rootwait}
    fi
    exec ${QEMU:-qemu-system-$target_arch} -nodefaults -no-user-config ${QEMU_FLAGS:-} \
        -no-reboot \
        "$@" \
        -append "${QEMU_APPEND:-} \
        ${ROOTFLAGS:-rootfstype=btrfs rootflags=subvol=root/$ROOT_VOLUME rw rootwait}" \
        -drive "file=$IMAGE,format=raw,if=${QEMU_DISK_IF:-sd}" \
        ${QEMU_EXTRA:-}
}
