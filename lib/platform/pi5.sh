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

# Pi 5 (BCM2712) is not yet emulated by QEMU; use raspi4b as closest approximation
readonly QEMU=qemu-system-aarch64
readonly QEMU_MACHINE=raspi4b
