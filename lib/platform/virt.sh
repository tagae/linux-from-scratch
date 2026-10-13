# The guest has the build machine's architecture, so that the accelerator can run it.
case "$(uname -m)" in
    arm64|aarch64)
        readonly target_arch=aarch64
        readonly kernel_arch=arm64
        readonly QEMU=qemu-system-aarch64
        readonly qemu_machine=virt
        ;;
    x86_64)
        readonly target_arch=x86_64
        readonly kernel_arch=x86_64
        readonly QEMU=qemu-system-x86_64
        readonly qemu_machine=q35
        ;;
    *) bail "Unsupported virt architecture '$(uname -m)'" ;;
esac
readonly kernel_machine=virt

case "$(uname -s)" in
    Darwin) readonly qemu_accel="-accel hvf" ;;
    Linux)  readonly qemu_accel="-accel kvm" ;;
esac

# Like a real machine, it has a USB host controller, for the USB devices given in QEMU_EXTRA.
readonly QEMU_FLAGS="\
    -M $qemu_machine -cpu host $qemu_accel -smp 1 -m 512 \
    -nographic \
    -device virtio-rng \
    -device qemu-xhci \
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
