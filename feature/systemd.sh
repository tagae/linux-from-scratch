# systemd, the init system and service manager: it mounts the file systems, runs the services and
# the journal, and keeps the clock across boots. It links util-linux's libmount and libblkid, kmod
# and libxcrypt, and runs agetty, sulogin and mount, from gnu, which also gives root its shell. It
# brings the static accounts, root's included.

# Requires: gnu
# Linux: systemd

lfs_system_install systemd
lfs_install_package systemd#dev
