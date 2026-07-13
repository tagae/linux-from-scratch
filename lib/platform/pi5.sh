readonly ARCH=arm64

readonly target=aarch64-${vendor:-scratch}-linux-gnu

# https://gcc.gnu.org/onlinedocs/gcc/AArch64-Options.html
readonly arch=armv8.2-a
readonly tune=cortex-a76
readonly abi=lp64
readonly fpu=
readonly float=

readonly kernel=kernel_2712
readonly defconfig=bcm2712_defconfig
readonly DTB=broadcom/bcm2712-rpi-5-b.dtb

# Pi 5 (BCM2712) is not yet emulated by QEMU; raspi4b is the closest
# approximation available. Not one of this project's required QEMU
# targets — best-effort only, and likely won't boot cleanly (the DTB
# describes real BCM2712 hardware the raspi4b model doesn't actually
# have). See pi4.sh for the flags themselves; identical here since
# they're both modeled as the same QEMU machine.
readonly QEMU=qemu-system-aarch64
readonly QEMU_FLAGS="\
    -M raspi4b -smp 4 -m 2048 \
    -display none \
    -serial mon:stdio -serial null"

readonly QEMU_APPEND="earlycon=pl011,0xfe201000 console=ttyAMA0,115200 \
    root=/dev/mmcblk0p2 rootdelay=5"

readonly QEMU_DISK_IF=sd

readonly IMAGE_LAYOUT=pi
