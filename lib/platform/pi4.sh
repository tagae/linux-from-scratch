readonly kernel_arch=arm64

readonly target=aarch64-scratch-linux-gnu

# https://gcc.gnu.org/onlinedocs/gcc/AArch64-Options.html
readonly arch=armv8-a
readonly tune=cortex-a72
readonly abi=lp64

readonly defconfig=bcm2711_defconfig
readonly dev_tree_blob=broadcom/bcm2711-rpi-4-b.dtb

readonly QEMU=qemu-system-aarch64

# raspi4b: QEMU fixes this model at exactly 2 GiB RAM.
# BCM2711 exposes two UARTs; QEMU wires the PL011 (ttyAMA0, our console) as the *first* serial
# and the mini-UART (ttyS0) as the second, so stdio must go on the first `-serial`,
# else the console output lands in null and nothing is visible.
readonly QEMU_FLAGS="\
    -M raspi4b -smp 4 -m 2048 \
    -display none \
    -serial mon:stdio -serial null"

# Kernel command line fragment specific to this platform.
#
# console=ttyAMA1 (not ttyAMA0): under QEMU raspi4b the rpi DTB's serial
# aliases make this PL011 register as ttyAMA1 (ttyAMA0 is the BT-side PL011).
# root=mmcblk1p2 (not p0): the SD image lands on the emmc2 controller, which
# enumerates as mmcblk1 (mmcblk0 is the SDIO/wifi mmcnr controller, cardless).
# maxcpus=1: the raspi4b model fixes -smp 4, but emulating 4 Cortex-A72 cores
# under TCG (no HVF for this machine) livelocks partway through boot ("sched:
# DL replenish lagged too much", guest time then frozen). Running the kernel
# UP is stable and faster; QEMU still presents all 4 CPUs, the kernel just
# uses one.
readonly QEMU_APPEND="earlycon=pl011,0xfe201000 console=ttyAMA1,115200 \
    root=/dev/mmcblk1p2 rootdelay=5 maxcpus=1"

# Serial console device; under QEMU raspi4b the console PL011 is ttyAMA1.
readonly CONSOLE=ttyAMA1

# Disk drive interface name.
readonly QEMU_DISK_IF=sd

# FAT boot partition (kernel.img/config.txt/DTB, for real hardware) + root.
readonly IMAGE_LAYOUT=pi
