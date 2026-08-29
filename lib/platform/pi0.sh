readonly target_arch=arm
readonly target_abi=gnueabihf

# https://gcc.gnu.org/onlinedocs/gcc/ARM-Options.html
readonly arch=armv6kz
readonly tune=arm1176jzf-s
readonly abi=aapcs-linux
readonly fpu=vfpv2
readonly float=hard

readonly defconfig=bcmrpi_defconfig
readonly DTB=bcm2835-rpi-zero.dtb

readonly QEMU=qemu-system-arm

# raspi0 emulates a BCM2835 SOC.
# mon:stdio connects the single UART (PL011) to the terminal; Ctrl-A C escapes to the QEMU monitor.
readonly QEMU_FLAGS="\
    -M raspi0 -m 512 \
    -display none \
    -serial mon:stdio"

# Kernel command line fragment specific to this platform.
# `rootdelay` lets the emulated SD card settle
# `initcall_blacklist` works around a known QEMU pm-driver hang on this machine model.
readonly QEMU_APPEND="earlycon=pl011,0x20201000 console=ttyAMA0,115200 \
    root=/dev/mmcblk0p2 rootdelay=5 \
    initcall_blacklist=bcm2835_pm_driver_init"

# Serial console device: BCM2835's PL011 is ttyAMA0.
readonly CONSOLE=ttyAMA0

# Disk drive interface name.
readonly QEMU_DISK_IF=sd

# FAT boot partition (kernel.img/config.txt/DTB, for real hardware).
readonly IMAGE_LAYOUT=pi
