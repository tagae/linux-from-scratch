# Opt-in "amnesia" capability (CAPS=amnesia): a genuinely read-only root
# filesystem with targeted tmpfs mounts for the state that must still be
# writable at runtime — increment #2 of the air-gapped GPG key-generation
# appliance (see SELF-HOST.md, GNUPG-YUBIKEY.md, package/gpg-genkey.sh).
# Design C: no overlayfs, no initrd. The root DEVICE itself is mounted ro
# (see lfs's qemu case and package/boot.sh's cmdline component, both
# cap-conditional on "amnesia" in $CAPS — package/linux/amnesia.config is
# the paired kernel-fragment half of this capability, comment-only since
# tmpfs/btrfs are already unconditional in base.config). This package is
# the userspace half: the fstab entries that put /var, /tmp and /root on
# tmpfs instead, plus the couple of fixups a ro root needs elsewhere.
# Proof of the whole thing: the disk image's hash is byte-identical before
# and after a full boot+use+poweroff cycle (see SELF-HOST.md).
# Only ever require()d when CAPS contains "amnesia" (see the bootable-*.sh
# umbrellas), so a build with CAPS unset installs none of this.
: ${package_version:=0.1.0}

install() {
    cd $package_install_dir

    # mkdir -p etc: this package's own stage dir starts empty (the stage->
    # archive->merge inversion, PACKAGING.md — see 9p-config.sh's own
    # comment on the same gotcha). /var and /root themselves are NOT
    # recreated here on purpose: system-files.sh already created them
    # (var/log, var/tmp, and root chmod 0750) in the tree these tmpfs
    # mounts land on top of at runtime — re-declaring them in this
    # package's own archive would risk merge order clobbering
    # system-files' permissions with mkdir -p's own umask-derived default.
    mkdir -pv etc

    # tmpfs mounts for the state that must stay writable on a ro root.
    #   /var  - logs, systemd's own runtime state (systemd-tmpfiles
    #           recreates the skeleton from /usr/lib/tmpfiles.d/var.conf —
    #           see the systemd case below).
    #   /tmp  - standard scratch space.
    #   /root - root's own shell history/scratch files; NOT load-bearing
    #           for gpg-genkey itself, whose GNUPGHOME already lives under
    #           /run (tmpfs, unconditionally — see gpg-genkey.sh).
    # systemd's own fstab-generator turns these into .mount units wired
    # into local-fs.target; the busybox flavor's rcS mounts fstab entries
    # itself via the S-script below (same drop-in mechanism 9p-config.sh's
    # S30 uses).
    cat > etc/fstab <<'EOF'
tmpfs /var tmpfs mode=755 0 0
tmpfs /tmp tmpfs mode=1777 0 0
tmpfs /root tmpfs mode=700 0 0
EOF

    # Empty (0-byte) /etc/machine-id. No package ships this file at all
    # today (system-files.sh doesn't, and nothing runs systemd-firstboot),
    # so a non-amnesia build is unaffected: systemd just creates
    # /etc/machine-id itself on first boot and persists it, same as always.
    # On a ro root that persist-to-disk write would fail (EROFS), so
    # instead systemd bind-mounts a tmpfs-backed transient ID over
    # /etc/machine-id for the current boot only (see machine-id(5)) — but a
    # bind mount needs an existing file to mount onto, hence shipping one
    # here (empty, not missing).
    : > etc/machine-id

    # gpg-genkey's `mkdir -p "$USB_MOUNT"` (/mnt/usb — see gpg-genkey.sh)
    # succeeds even on a ro filesystem when the directory already exists
    # (mkdir -p only fails trying to CREATE something new), so ship the
    # mountpoint here rather than relying on gpg-genkey to create it at
    # runtime. Nothing else creates /mnt at all (system-files.sh doesn't;
    # same reasoning as 9p-config.sh's own mkdir -pv mnt/lfs).
    mkdir -pv mnt/usb

    case $INIT in
        systemd)
            # tmp.mount's own mask (which would otherwise beat the fstab
            # generator and leave /tmp stuck on the ro root) is skipped at
            # the SOURCE, in package/systemd.sh's own install(), not
            # reversed here. A package's package_install_dir is its own
            # fresh, empty per-package stage dir (the stage->archive->merge
            # inversion, PACKAGING.md) — an `rm -fv` in THIS package's
            # install() only ever removes a path from THIS package's own
            # (never populated) stage, so it can never reach back and
            # delete something an earlier package (systemd) already merged;
            # merge only adds/overwrites paths a package's own tarball
            # contains. Confirmed empirically the hard way, building this
            # capability — see package/systemd.sh's own comment on its
            # tmp.mount line for the full account (network-config.sh's
            # systemd-networkd unmask has this identical, currently
            # unfixed, bug).
            ;;
        busybox)
            # busybox-init.sh's rcS already mounts /run and /tmp itself,
            # unconditionally, before any capability drop-in runs — so the
            # /tmp entry in the fstab above is a no-op here (busybox's own
            # `mount -a` skips a directory that already has something
            # mounted on it, confirmed against its util-linux/mount.c).
            # Only /var and /root actually need mounting. Reuses the
            # established drop-in mechanism (network-config.sh's
            # S40network, 9p-config.sh's S30mount-9p).
            mkdir -pv etc/init.d
            cat > etc/init.d/S20mount-amnesia <<'EOF'
#!/bin/sh
mount -a

# Recreate the handful of /var/log accounting files login/getty write to
# (system-files.sh touches these same paths at image-build time, but /var
# is now a fresh tmpfs on every boot, so that baked copy is shadowed).
# Kept minimal on purpose — just what login/getty actually use; utmp
# itself is /run/utmp, already tmpfs via rcS's own /run mount.
mkdir -p /var/log
touch /var/log/btmp /var/log/lastlog /var/log/faillog /var/log/wtmp
chgrp utmp /var/log/lastlog 2>/dev/null || true
chmod 0664 /var/log/lastlog
chmod 0600 /var/log/btmp
EOF
            chmod -v 0755 etc/init.d/S20mount-amnesia
            ;;
    esac
}
