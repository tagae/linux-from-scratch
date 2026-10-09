# Opt-in "9p" capability (CAPS=9p): mounts the project directory shared by
# QEMU's virtio-9p device (see lfs's qemu case) at /mnt/lfs in the guest.
# Installed only when CAPS contains "9p".
: ${package_version:=0.1.0}

install() {
    cd $package_install_dir

    mkdir -pv mnt/lfs etc

    # nofail: don't block boot if the share isn't attached (e.g. this same
    # image booted without CAPS=9p, or on a platform/QEMU invocation with
    # no virtio bus at all — see lfs's qemu case, virt-only for now).
    # systemd's fstab-generator honors nofail on its own (auto-mounted via
    # the generated unit, but not required by local-fs.target).
    cat > etc/fstab <<'EOF'
lfs /mnt/lfs 9p trans=virtio,version=9p2000.L,nofail 0 0
EOF
}
