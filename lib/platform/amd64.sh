# A 64-bit x86 PC, tested as QEMU's q35 machine.
readonly target_arch=x86_64
readonly kernel_arch=x86_64
# Virtio devices on PCI Express, as in every QEMU virtual machine.
readonly kernel_machine=virt

readonly QEMU=qemu-system-x86_64

# QEMU uses the first accelerator available: KVM or HVF on x86-64 hosts, emulation (TCG) elsewhere.
readonly QEMU_FLAGS="\
    -M q35 -cpu max -accel kvm -accel hvf -accel tcg -smp 1 -m 512 \
    -display none \
    -device virtio-rng-pci \
    -serial mon:stdio"

# Kernel command line fragment specific to this platform.
readonly QEMU_APPEND="console=ttyS0 root=/dev/vda1"

# Serial console device: the PC's first UART.
readonly CONSOLE=ttyS0

# Disk drive interface name.
readonly QEMU_DISK_IF=virtio

# Single BTRFS partition. QEMU loads kernel directly, so no boot partition.
readonly IMAGE_LAYOUT=single
