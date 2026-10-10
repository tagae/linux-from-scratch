readonly kernel_arch=arm64

readonly target=aarch64-scratch-linux-gnu

# https://gcc.gnu.org/onlinedocs/gcc/AArch64-Options.html
readonly arch=armv8.2-a
readonly tune=cortex-a76
readonly abi=lp64

readonly defconfig=bcm2712_defconfig
readonly dev_tree_blob=broadcom/bcm2712-rpi-5-b.dtb

# QEMU does not support Pi 5 (BCM2712) emulation.

# Serial console device.
readonly CONSOLE=ttyAMA0

readonly IMAGE_LAYOUT=pi
