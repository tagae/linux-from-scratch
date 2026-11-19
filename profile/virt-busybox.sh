# A bare-bones BusyBox virtual machine.

lfs_system_toolchain musl

(
    applets="archival console-tools coreutils debianutils editors findutils init loginutils"
    applets="$applets miscutils networking procps shell util-linux"
    lfs_system_install busybox
)

( capabilities="btrfs console devtmpfs hardening"; lfs_system_install linux )
