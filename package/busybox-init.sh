# Boot-time configuration for the busybox-init flavor: /etc/inittab (read by
# busybox init as PID 1) and /etc/init.d/rcS (its one-shot sysinit script).
# The systemd flavor needs none of this — systemd is its own PID 1 — so this
# package is a member of bootable-busybox only. No source to build; it just
# writes two generated files, so it has a version purely for the framework's
# path derivation (see system-files.sh / boot.sh for the same pattern).
: ${package_version:=0.1.0}

install() {
    mkdir -pv $package_install_dir/etc/init.d

    # busybox init runs getty on the platform's serial console ($CONSOLE,
    # from lib/platform/$PLATFORM.sh: hvc0 on virt, ttyAMA0/1 on the Pis).
    # The leading field is the controlling tty (relative to /dev); -L keeps
    # getty from waiting on carrier-detect, which a virtual UART never
    # asserts. ctrlaltdel/shutdown give a clean path for `reboot`/`poweroff`
    # (busybox init signals itself, runs the shutdown action, then the
    # syscall) so QEMU exits under -no-reboot instead of hanging.
    cat > $package_install_dir/etc/inittab <<EOF
::sysinit:/etc/init.d/rcS
$CONSOLE::respawn:/sbin/getty -L 115200 $CONSOLE vt100
::ctrlaltdel:/sbin/reboot
::shutdown:/bin/umount -a -r
::restart:/sbin/init
EOF

    # devtmpfs is auto-mounted by the kernel (CONFIG_DEVTMPFS_MOUNT=y in
    # package/linux/base.config), so /dev is already populated; rcS only has
    # to bring up the remaining pseudo-filesystems and set the hostname. The
    # root fs is already mounted rw by the kernel (rootflags rw).
    cat > $package_install_dir/etc/init.d/rcS <<EOF
#!/bin/sh
mount -t proc  proc  /proc
mount -t sysfs sysfs /sys
mount -t tmpfs tmpfs /run
mount -t tmpfs tmpfs /tmp
hostname ${MACHINE:-lfs}

# Run any capability's own startup script dropped into /etc/init.d (e.g.
# network-config's S40network, 9p-config's S30mount-9p) — a generic
# mechanism so no future capability needs its own edit here. With no such
# script present the glob is left unmatched (this shell's own doing, not
# the scripts'), so [ -x ] on the literal pattern is simply false and a
# no-caps boot is unchanged.
for f in /etc/init.d/S*; do
    [ -x "\$f" ] && "\$f"
done
EOF
    chmod -v 0755 $package_install_dir/etc/init.d/rcS
}
