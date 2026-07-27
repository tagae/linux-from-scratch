# Boot the built system's image in QEMU: `lfs qemu [IMAGE]`, IMAGE
# defaulting to this SYSTEM_KEY's own image. Runs directly on the
# development host (not in a container) — the kernel/DTB come from
# WORK_DIR/boot, bind-mounted to the host precisely so this command can
# read them (see docker-compose.yaml and lib/system.sh); the machine
# model, console and disk wiring come from the platform file (QEMU,
# QEMU_FLAGS, QEMU_APPEND, QEMU_DISK_IF), and the capability set (CAPS)
# gates the optional devices below.
qemu() {
    [ $# -le 1 ] || usage "qemu [IMAGE]"
    IMAGE="${1:-$IMAGE_DIR/$SYSTEM_KEY.img}"
    local kernel="$WORK_DIR/boot/$SYSTEM_KEY/kernel.img"
    [ -f "$kernel" ] || bail "Kernel not found: $kernel (run './lfs system build' first)"
    set -- -kernel "$kernel"
    if [ -n "${DTB:-}" ]; then
        local dtb="$WORK_DIR/boot/$SYSTEM_KEY/$DTB"
        [ -f "$dtb" ] || bail "DTB not found: $dtb (run './lfs system build' first)"
        set -- "$@" -dtb "$dtb"
    fi
    # Capability-gated QEMU devices. Both are virtio-pci, so they only
    # make sense where there's a PCI bus (virt); the Pi machine models
    # have none — real hardware support for these capabilities is
    # separate future work, not something to guard against here.
    if has_cap network; then
        set -- "$@" -netdev user,id=net0 -device virtio-net-pci,netdev=net0
    fi
    if has_cap 9p; then
        set -- "$@" \
            -fsdev local,id=lfs,path=$PROJECT_DIR,security_model=mapped-xattr \
            -device virtio-9p-pci,fsdev=lfs,mount_tag=lfs
    fi
    # Removable USB stick for the air-gapped GPG key-persist workflow
    # (see package/gpg-genkey.sh). Two attach forms, chosen by
    # $PLATFORM: virt has no dwc2 (only QEMU's PCI-attached qemu-xhci,
    # itself needing a PCI bus, which only virt's machine model
    # provides), while the Pi machine models (pi0 here; real hardware
    # has no PCI bus at all) expose their SoC's own dwc2 OTG controller
    # instead — QEMU's raspi0 machine models it as a plain usb-bus (id
    # "usb-bus.0", confirmed empirically via `info qtree`/`info usb` on
    # a bare `-M raspi0`: `dev: dwc2-usb ... bus: usb-bus.0`), so
    # usb-storage attaches straight to it with no controller device of
    # its own to instantiate first (unlike xhci, which needs one).
    # USB_DISK must already exist (e.g. a blank vfat image created on
    # the host); unset/empty is a no-op, so a usb-capable build with no
    # stick attached still boots (just with no USB device present, same
    # as the network/9p caps above only wiring up when the guarding env
    # var/CAPS conditions hold). The virt root disk itself is
    # virtio-blk (/dev/vda, see QEMU_DISK_IF above) and pi0's is the SD
    # card (/dev/mmcblk0, QEMU_DISK_IF=sd) — either way this stick
    # enumerates as the guest's first SCSI/USB-storage disk, /dev/sda.
    if has_cap usb && [ -n "${USB_DISK:-}" ]; then
        [ -f "$USB_DISK" ] || bail "USB_DISK not found: $USB_DISK"
        # cache=writethrough: every guest write is committed to
        # $USB_DISK on the host as soon as the guest's own
        # sync()/umount() say it's durable, rather than trusting
        # QEMU's own write-back cache to still be intact by the
        # time this same file is read back later (e.g. the host-
        # side verification step, or a later boot with a fresh
        # guest that never issues its own flush). This stick
        # models removable media a guest can yank at any time
        # (that's the whole point of the appliance — see
        # gpg-genkey.sh): its persistence contract should rest on
        # the guest's own explicit sync, not on however cleanly
        # this particular QEMU process happens to exit afterward.
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
    # Cap-conditional read-only root (CAPS=amnesia — increment #2 of the
    # air-gapped GPG appliance; see package/amnesia-config.sh). Sets
    # ROOTFLAGS's own DEFAULT here,
    # rather than touching the "${ROOTFLAGS:-...}" fallback in the
    # -append line below, so: (a) ROOTFLAGS's existing override contract
    # (any caller can still set it directly) is untouched, and (b) the
    # no-amnesia fallback text below stays byte-identical to what it was
    # before this capability existed. rescue=nologreplay: btrfs replays
    # its crash-consistency log tree at mount time even under `ro` —
    # that replay writes to the device — so without this a "read-only"
    # mount would still, occasionally, touch the boot medium;
    # rescue=nologreplay is what actually makes the hash-identical proof
    # hold (verified by comparing the image file's SHA-256 across a
    # full boot->keygen->poweroff cycle: byte-identical, i.e. the boot
    # medium really is never written). NOT the bare "nologreplay"
    # spelling: this
    # kernel's btrfs (7.1.2) rejects it outright ("Unknown parameter
    # 'nologreplay'", a boot-time kernel panic — confirmed empirically)
    # — the older standalone option was consolidated into the "rescue="
    # namespace and the bare alias no longer parses.
    if has_cap amnesia; then
        : ${ROOTFLAGS:=rootfstype=btrfs rootflags=subvol=root/$ROOT_VOLUME,rescue=nologreplay ro rootwait}
    fi
    # QEMU_EXTRA last: QEMU's own "last flag wins" rule for repeated
    # options (-smp/-m/...) lets this override QEMU_FLAGS's defaults
    # (e.g. the self-host builder guest needs more than virt's default
    # -smp 1 -m 512 to build a whole system natively) without editing
    # the platform file itself. Empty by default,
    # so an unset QEMU_EXTRA changes nothing.
    exec $QEMU -nodefaults -no-user-config ${QEMU_FLAGS:-} \
        -no-reboot \
        "$@" \
        -append "${QEMU_APPEND:-} ${ROOTFLAGS:-rootfstype=btrfs rootflags=subvol=root/$ROOT_VOLUME rw rootwait}" \
        -drive "file=$IMAGE,format=raw,if=${QEMU_DISK_IF:-sd}" \
        ${QEMU_EXTRA:-}
}
