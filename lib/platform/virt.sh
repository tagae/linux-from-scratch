case "$(uname -m)" in
    arm64|aarch64) # Varies according to OS.
        readonly ARCH=arm64
        readonly target=aarch64-${vendor:-scratch}-linux-gnu
        readonly QEMU=qemu-system-aarch64
        ;;
    *) bail "Unsupported virt architecture" ;;
esac

readonly QEMU_MACHINE=virt
readonly QEMU_FLAGS="-cpu host -smp 1 -m 512 \
    -nographic \
    -device virtio-rng \
    -device virtio-serial \
    -chardev stdio,signal=off,mux=on,id=char0 \
    -device virtconsole,chardev=char0,id=console0 \
    -mon chardev=char0,mode=readline"
readonly QEMU_DISK_IF=virtio

# Single btrfs partition — no FAT boot partition (QEMU loads kernel directly)
readonly IMAGE_LAYOUT=single
