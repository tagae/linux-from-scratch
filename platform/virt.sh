# A QEMU virtual machine of the build machine's architecture.

# The guest has the build machine's architecture, so that the accelerator can run it.
case "$(uname -m)" in
    arm64|aarch64)
        readonly target_arch=aarch64
        readonly kernel_arch=arm64
        readonly qemu_system=qemu-system-aarch64
        # No PCI window above 4 GiB: its size, 512 GiB, is more than the 32 bits that the kernel
        # expects of a window for non-prefetchable memory, and it warns about it at every boot. The
        # window below 4 GiB, of 768 MiB, is all that the devices of this machine need.
        readonly qemu_machine=virt,highmem-mmio=off
        ;;
    x86_64)
        readonly target_arch=x86_64
        readonly kernel_arch=x86_64
        readonly qemu_system=qemu-system-x86_64
        readonly qemu_machine=q35
        ;;
    *) bail "Unsupported virt architecture '$(uname -m)'" ;;
esac

case "$(uname -s)" in
    Darwin) readonly qemu_accel="-accel hvf" ;;
    Linux)  readonly qemu_accel="-accel kvm" ;;
esac

# Like a real machine, it has a USB host controller, for the USB devices given in LFS_QEMU_EXTRA.
readonly qemu_flags="\
    -M $qemu_machine -cpu host $qemu_accel -smp 1 -m 512 \
    -nographic \
    -device virtio-rng \
    -device qemu-xhci \
    -device virtio-serial \
    -chardev stdio,signal=off,mux=on,id=char0 \
    -device virtconsole,chardev=char0,id=console0 \
    -object monitor-hmp,id=mon0,chardev=char0"

# Kernel command line fragment specific to this platform.
readonly qemu_append="console=hvc0 root=/dev/vda1"

# Disk drive interface name.
readonly qemu_disk_if=virtio

# Single BTRFS partition. QEMU loads kernel directly, so no boot partition.
readonly image_layout=single
