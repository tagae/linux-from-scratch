case "$(uname -s)" in
    Darwin) readonly qemu_accel="-accel hvf" ;;
    Linux)  readonly qemu_accel="-accel kvm" ;;
esac

readonly QEMU_FLAGS="\
    -M virt -cpu host $qemu_accel -smp 1 -m 512 \
    -nographic \
    -device virtio-rng \
    -device virtio-serial \
    -chardev stdio,signal=off,mux=on,id=char0 \
    -device virtconsole,chardev=char0,id=console0 \
    -mon chardev=char0,mode=readline"

# Kernel command line fragment specific to this platform.
readonly QEMU_APPEND="console=hvc0 root=/dev/vda1"

# Serial console device. The QEMU virtio-console enumerates as hvc0.
readonly CONSOLE=hvc0

# Disk drive interface name.
readonly QEMU_DISK_IF=virtio

# Single BTRFS partition. QEMU loads kernel directly, so no boot partition.
readonly IMAGE_LAYOUT=single
