readonly ARCH=arm64

readonly target=aarch64-${vendor:-scratch}-linux-gnu

# https://gcc.gnu.org/onlinedocs/gcc/AArch64-Options.html
readonly arch=armv8-a
readonly tune=cortex-a72
readonly abi=lp64
readonly fpu=
readonly float=

readonly kernel=kernel8
readonly defconfig=bcm2711_defconfig
readonly DTB=broadcom/bcm2711-rpi-4-b.dtb

readonly QEMU=qemu-system-aarch64
readonly QEMU_MACHINE=raspi4b
