# Opt-in "amnesia" capability (CAPS=amnesia): a read-only root filesystem with
# targeted tmpfs mounts for the state that must still be writable at runtime.
# No overlayfs, no initrd: the root device itself is mounted ro (see lfs's qemu
# case and package/boot.sh's cmdline component, both conditional on "amnesia"
# in $CAPS), and package/linux/amnesia.config is the paired kernel half. This
# package is the userspace half: fstab entries putting /var, /tmp and /root on
# tmpfs, plus the fixups a ro root needs elsewhere. The disk image stays
# byte-identical across a boot+use+poweroff cycle.
# Installed only when CAPS contains "amnesia".
: ${package_version:=0.1.0}

install() {
    cd $package_install_dir

    # /var and /root themselves are not created here: system-files.sh already
    # creates them (var/log, var/tmp, and root chmod 0750) in the tree these
    # tmpfs mounts land on, and shipping them again could overwrite
    # system-files' permissions with mkdir's umask-derived ones.
    mkdir -pv etc

    # tmpfs mounts for the state that must stay writable on a ro root, which
    # systemd's fstab-generator turns into .mount units:
    #   /var  - logs and systemd's runtime state (systemd-tmpfiles recreates
    #           the skeleton from /usr/lib/tmpfiles.d/var.conf).
    #   /tmp  - standard scratch space (package/systemd.sh leaves tmp.mount
    #           unmasked under this capability, so this entry takes effect).
    #   /root - root's shell history and scratch files.
    cat > etc/fstab <<'EOF'
tmpfs /var tmpfs mode=755 0 0
tmpfs /tmp tmpfs mode=1777 0 0
tmpfs /root tmpfs mode=700 0 0
EOF

    # Empty (0-byte) /etc/machine-id. Without this capability no package ships
    # the file, and systemd creates and persists it on first boot. On a ro root
    # that write fails (EROFS), so systemd instead bind-mounts a transient ID
    # over /etc/machine-id for the current boot (see machine-id(5)), which needs
    # an existing file to mount onto.
    : > etc/machine-id

    # A ro root can't gain mountpoints at runtime, so ship one for the usb
    # capability's disk (see lib/qemu.sh). Nothing else creates /mnt.
    mkdir -pv mnt/usb
}
