readonly ARCH=arm

readonly target=arm-${vendor:-scratch}-linux-gnueabihf

# https://gcc.gnu.org/onlinedocs/gcc/ARM-Options.html
readonly arch=armv6kz
readonly tune=arm1176jzf-s
readonly abi=aapcs-linux
readonly fpu=vfpv2
readonly float=hard

readonly kernel=kernel
readonly defconfig=bcmrpi_defconfig
readonly DTB=bcm2835-rpi-zero.dtb

readonly QEMU=qemu-system-arm
# raspi0 (BCM2835): single-core ARM1176, 512 MiB, no HVF/KVM possible for
# a 32-bit ARM guest — TCG software emulation only, matching real
# hardware. BCM2835 has just one UART (PL011); mon:stdio connects it to
# our terminal (and allows Ctrl-A C to escape to the QEMU monitor).
readonly QEMU_FLAGS="\
    -M raspi0 -m 512 \
    -display none \
    -serial mon:stdio"

# Kernel command line fragment specific to this platform (combined with
# the filesystem-related fragment in `lfs`'s qemu case under a single
# -append). root is the 2nd (btrfs) partition of the SD image; rootdelay
# lets the emulated SD card settle; initcall_blacklist works around a
# known QEMU pm-driver hang on this machine model.
readonly QEMU_APPEND="earlycon=pl011,0x20201000 console=ttyAMA0,115200 \
    root=/dev/mmcblk0p2 rootdelay=5 \
    initcall_blacklist=bcm2835_pm_driver_init"

# Serial console device the busybox-init flavor runs getty on (see
# package/busybox-init.sh). BCM2835's PL011 is ttyAMA0.
readonly CONSOLE=ttyAMA0

readonly QEMU_DISK_IF=sd

# FAT boot partition (kernel.img/config.txt/DTB, for real hardware) + btrfs root.
readonly IMAGE_LAYOUT=pi
