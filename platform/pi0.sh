# A Raspberry Pi Zero, whose firmware boots the kernel from the FAT partition of the Pi layout.

readonly kernel_arch=arm
readonly target_arch=arm
readonly target_abi=gnueabihf

# https://gcc.gnu.org/onlinedocs/gcc/ARM-Options.html
readonly target_gcc_arch=armv6kz
readonly target_gcc_tune=arm1176jzf-s
readonly target_gcc_abi=aapcs-linux
readonly target_gcc_fpu=vfpv2
readonly target_gcc_float=hard

readonly defconfig=bcmrpi_defconfig
readonly dev_tree_blob=broadcom/bcm2835-rpi-zero.dtb

# What the SoC's boot ROM loads from the FAT boot partition: the bootloader, and the GPU firmware
# that starts the kernel.
readonly firmware_files="bootcode.bin start.elf fixup.dat"

readonly QEMU=qemu-system-arm

# raspi0 emulates a BCM2835 SOC.
# mon:stdio connects the single UART (PL011) to the terminal; Ctrl-A C escapes to the QEMU monitor.
readonly QEMU_FLAGS="\
    -M raspi0 -m 512 \
    -display none \
    -serial mon:stdio"

# Kernel command line fragment specific to this platform: the serial console, and the root file
# system on the SD card's second partition.
readonly kernel_cmdline="earlycon=pl011,0x20201000 console=ttyAMA0,115200 root=/dev/mmcblk0p2"

# Under QEMU, `rootdelay` lets the emulated SD card settle, and `initcall_blacklist` works around a
# known QEMU pm-driver hang on this machine model.
readonly QEMU_APPEND="$kernel_cmdline rootdelay=5 initcall_blacklist=bcm2835_pm_driver_init"

# Serial console device: BCM2835's PL011 is ttyAMA0.
readonly CONSOLE=ttyAMA0

# Disk drive interface name.
readonly QEMU_DISK_IF=sd

# FAT boot partition (kernel.img/config.txt/DTB, for real hardware).
readonly IMAGE_LAYOUT=pi
