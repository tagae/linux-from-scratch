# A bare-bones virtual machine, to show that the system boots cleanly, that root logs in on the
# console, and that it powers off: musl as the C library, and BusyBox as init, shell (ash, which is
# /bin/sh) and core utilities, with musl's crypt(3) for login's password check. BusyBox has every
# applet that these kernels can serve. The kernel has a console, the btrfs root file system,
# devtmpfs and hardening. It brings the static accounts, root's included.

lfs_system_toolchain musl

(
    applets="archival console-tools coreutils debianutils e2fsprogs editors findutils init"
    applets="$applets klibc-utils loginutils mailutils miscutils modutils networking procps"
    applets="$applets runit shell util-linux"
    lfs_system_install busybox
)

( capabilities="btrfs console devtmpfs hardening"; lfs_system_install linux )
