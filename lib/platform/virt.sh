case "$(uname -m)" in
    arm64|aarch64) # Varies according to OS.
        readonly ARCH=arm64
        readonly target=aarch64-${vendor:-scratch}-linux-gnu
        readonly QEMU=qemu-system-aarch64
        ;;
    *) bail "Unsupported virt architecture" ;;
esac

case "$(uname -s)" in
    Darwin) readonly QEMU_CPU="-accel hvf -cpu host" ;;
    Linux)  readonly QEMU_CPU="-accel kvm -cpu host" ;;
esac

readonly QEMU_FLAGS="\
    -M virt $QEMU_CPU -smp 1 -m 512 \
    -nographic \
    -device virtio-rng \
    -device virtio-serial \
    -chardev stdio,signal=off,mux=on,id=char0 \
    -device virtconsole,chardev=char0,id=console0 \
    -mon chardev=char0,mode=readline"

# Kernel command line fragment specific to this platform.
readonly QEMU_APPEND="console=hvc0 root=/dev/vda1"

# Serial console device. The QEMU virtio-console above enumerates as hvc0.
readonly CONSOLE=hvc0

readonly QEMU_DISK_IF=virtio

# Single BTRFS partition. QEMU loads kernel directly, so no boot partition.
readonly IMAGE_LAYOUT=single
