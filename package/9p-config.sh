# Opt-in "9p" capability (CAPS=9p): mounts the project directory shared by
# QEMU's virtio-9p device (see lfs's qemu case) at /mnt/lfs in the guest —
# groundwork for a later self-hosted-build objective. Only ever require()d
# when CAPS contains "9p" (see the bootable-*.sh umbrellas), so a build
# with CAPS unset installs none of this.
: ${package_version:=0.1.0}

install() {
    cd $package_install_dir

    mkdir -pv mnt/lfs

    # mkdir -p etc: this package's own stage dir starts empty (the stage->
    # archive->merge inversion, PACKAGING.md — package_install_dir is a
    # fresh per-package dir now, not the already-populated shared merged
    # tree system-files created etc/ in). Found the hard way (SELF-HOST.md
    # M4): without this, `cat > etc/fstab` below failed with ENOENT and —
    # due to a separate, now-fixed _once() bug (lib/package.sh) — that
    # failure was silently swallowed instead of aborting the build, so this
    # went undetected since M3 landed: every CAPS=9p image since then
    # shipped with NO /etc/fstab at all, and the 9p share never mounted.
    mkdir -pv etc

    # nofail: don't block boot if the share isn't attached (e.g. this same
    # image booted without CAPS=9p, or on a platform/QEMU invocation with
    # no virtio bus at all — see lfs's qemu case, virt-only for now).
    # systemd's fstab-generator honors nofail on its own (auto-mounted via
    # the generated unit, but not required by local-fs.target); the
    # busybox flavor's rcS drop-in below relies on busybox's own
    # recognition of the option (needs CONFIG_DESKTOP=y, which
    # package/busybox.sh's defconfig-based build carries).
    cat > etc/fstab <<'EOF'
lfs /mnt/lfs 9p trans=virtio,version=9p2000.L,nofail 0 0
EOF

    case $INIT in
        busybox)
            # systemd auto-generates a mount unit from fstab (see above);
            # busybox has no such generator, so rcS has to mount fstab
            # entries itself. Reuses the same capability drop-in mechanism
            # network-config's busybox half added to /etc/init.d — 'mount
            # -a' mounts every entry not yet mounted (nothing else is in
            # fstab, so this only ever touches /mnt/lfs).
            mkdir -pv etc/init.d
            cat > etc/init.d/S30mount-9p <<'EOF'
#!/bin/sh
mount -a
EOF
            chmod -v 0755 etc/init.d/S30mount-9p
            ;;
    esac
}
