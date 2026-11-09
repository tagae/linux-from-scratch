# What the Raspberry Pi firmware boots from, on the FAT partition of the Pi layout: the bootloader
# and the GPU firmware, which start the kernel, the firmware's configuration and the kernel command
# line. The pi0 platform requires it.

lfs_system_install firmware
lfs_system_install boot
