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
# UARTs; QEMU wires the PL011 (ttyAMA0, our console) as the *first* serial
# and the mini-UART (ttyS0) as the second — so stdio must go on the first
# -serial, else the console output lands in null and nothing is visible.
# -display none: this is a headless serial-console boot, no graphics window.
readonly QEMU_FLAGS="\
    -M raspi4b -smp 4 -m 2048 \
    -display none \
    -serial mon:stdio -serial null"

# Kernel command line fragment specific to this platform (combined with
# the filesystem-related fragment in `lfs`'s qemu case under a single
# -append). BCM2711's PL011 base differs from BCM2835's (pi0.sh) —
# 0xfe201000 vs 0x20201000.
#
# console=ttyAMA1 (not ttyAMA0): under QEMU raspi4b the rpi DTB's serial
# aliases make this PL011 register as ttyAMA1 (ttyAMA0 is the BT-side PL011);
# pointing the console at ttyAMA0 gives "unable to open an initial console".
# root=mmcblk1p2 (not p0): the SD image lands on the emmc2 controller, which
# enumerates as mmcblk1 (mmcblk0 is the SDIO/wifi mmcnr controller, cardless).
# maxcpus=1: the raspi4b model fixes -smp 4, but emulating 4 Cortex-A72 cores
# under TCG (no HVF for this machine) livelocks partway through boot ("sched:
# DL replenish lagged too much", guest time then frozen). Running the kernel
# UP is stable and faster; QEMU still presents all 4 CPUs, the kernel just
# uses one.
readonly QEMU_APPEND="earlycon=pl011,0xfe201000 console=ttyAMA1,115200 \
    root=/dev/mmcblk1p2 rootdelay=5 maxcpus=1"

# Serial console device the busybox-init flavor runs getty on (see
# package/busybox-init.sh). Under QEMU raspi4b the console PL011 is ttyAMA1
# (see the console= note above).
readonly CONSOLE=ttyAMA1

readonly QEMU_DISK_IF=sd

# FAT boot partition (kernel.img/config.txt/DTB, for real hardware) + btrfs root.
readonly IMAGE_LAYOUT=pi
