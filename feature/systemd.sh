# systemd, the init system and service manager: it mounts the file systems, runs the services and
# the journal, and keeps the clock across boots. It links util-linux's libmount and libblkid, kmod
# and libxcrypt, and runs agetty, sulogin and mount. What it needs of the kernel is the userland's
# layer of the kernel configuration, package/linux/systemd-gnu.config.

# Requires: gnu

lfs_system_install systemd
lfs_install_package systemd#dev
