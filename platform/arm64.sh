# A 64-bit ARM machine, tested as QEMU's virt machine.

# Requires: linux

readonly target_arch=aarch64
readonly kernel_arch=arm64
# Virtio devices on PCI Express, as in every QEMU virtual machine.
readonly kernel_machine=virt

readonly QEMU=qemu-system-aarch64

# QEMU uses the first accelerator available: KVM or HVF on ARM hosts, emulation (TCG) elsewhere.
# Like a real machine, it has a USB host controller, for the USB devices given in QEMU_EXTRA.
readonly QEMU_FLAGS="\
    -M virt -cpu max -accel kvm -accel hvf -accel tcg -smp 1 -m 512 \
    -display none \
    -device virtio-rng-pci \
    -device qemu-xhci \
    -serial mon:stdio"

# Kernel command line fragment specific to this platform.
readonly QEMU_APPEND="console=ttyAMA0 root=/dev/vda1"

# Serial console device: the machine's PL011 UART.
readonly CONSOLE=ttyAMA0

# Disk drive interface name.
readonly QEMU_DISK_IF=virtio

# Single BTRFS partition. QEMU loads kernel directly, so no boot partition.
readonly IMAGE_LAYOUT=single
