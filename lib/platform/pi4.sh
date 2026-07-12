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
# raspi4b: QEMU fixes this model at 4x Cortex-A72 and exactly 2 GiB RAM —
# both flags are mandatory, not just defaults. TCG only: the raspi4b
# model doesn't support HVF passthrough the way -M virt does, even
# though this is an aarch64 guest on an aarch64 host. BCM2711 exposes two
# UARTs (PL011 + mini-UART); model both, PL011 (ttyAMA0) is the console.
readonly QEMU_FLAGS="\
    -M raspi4b -smp 4 -m 2048 \
    -serial null -serial mon:stdio"

# Kernel command line fragment specific to this platform (combined with
# the filesystem-related fragment in `lfs`'s qemu case under a single
# -append). root is the 2nd (btrfs) partition of the SD image. BCM2711's
# PL011 base differs from BCM2835's (pi0.sh) — 0xfe201000 vs 0x20201000.
readonly QEMU_APPEND="earlycon=pl011,0xfe201000 console=ttyAMA0,115200 \
    root=/dev/mmcblk0p2 rootdelay=5"

readonly QEMU_DISK_IF=sd

# FAT boot partition (kernel.img/config.txt/DTB, for real hardware) + btrfs root.
readonly IMAGE_LAYOUT=pi
