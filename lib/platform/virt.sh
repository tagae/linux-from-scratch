readonly ARCH=arm64

readonly target=aarch64-${vendor:-scratch}-linux-gnu

# https://gcc.gnu.org/onlinedocs/gcc/AArch64-Options.html
readonly arch=armv8-a
readonly tune=
readonly abi=lp64
readonly fpu=
readonly float=

readonly QEMU=qemu-system-aarch64
readonly QEMU_MACHINE=virt
readonly QEMU_FLAGS="-cpu cortex-a72 -smp 1 -m 512 \
    -nographic \
    -device virtio-rng \
    -device virtio-serial \
    -chardev stdio,signal=off,mux=on,id=char0 \
    -device virtconsole,chardev=char0,id=console0 \
    -mon chardev=char0,mode=readline"
readonly QEMU_DISK_IF=virtio

# Single btrfs partition — no FAT boot partition (QEMU loads kernel directly)
readonly IMAGE_LAYOUT=single
