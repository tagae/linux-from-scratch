: ${package_version:=0.1.0}

install() {
    cd $package_install_dir

    # Create the real directory tree under /usr
    mkdir -pv \
          usr/bin usr/sbin usr/lib usr/lib64 \
          usr/include usr/share \
          boot dev etc \
          proc root run sys tmp \
          var/log var/tmp

    # Compatibility symlinks (merged-usr layout: /bin, /sbin, /lib -> usr/*)
    # These must be created BEFORE any package installs to /bin, /sbin, /lib
    ln -sfv usr/bin  bin
    ln -sfv usr/sbin sbin
    ln -sfv usr/lib  lib
    ln -sfv usr/lib  lib64

    chmod -v 0750 root
    chmod -v 1777 tmp var/tmp

    ln -sfv /proc/self/mounts etc/mtab
    ln -sfv /run var/run
    ln -sfv /run/lock var/lock

    cp -rv $package_files_dir/* .

    touch var/log/btmp var/log/lastlog var/log/faillog var/log/wtmp
    chgrp -v 13 var/log/lastlog 2>/dev/null || true  # 13 is utmp
    chmod -v 0664 var/log/lastlog
    chmod -v 0600 var/log/btmp

    # Mask units that cannot work or are not needed in this minimal build
    mkdir -pv \
          etc/systemd/system \
          etc/systemd/system-generators

    # systemd-logind requires PAM (built without it); mask socket too
    ln -sfv /dev/null etc/systemd/system/systemd-logind.service
    ln -sfv /dev/null etc/systemd/system/systemd-logind-varlink.socket

    # systemd-gpt-auto-generator fails on btrfs /dev/root pseudo-device
    ln -sfv /dev/null etc/systemd/system-generators/systemd-gpt-auto-generator

    # Network services — not needed for minimal serial-console boot
    ln -sfv /dev/null etc/systemd/system/systemd-resolved.service
    ln -sfv /dev/null etc/systemd/system/systemd-networkd.service
    ln -sfv /dev/null etc/systemd/system/systemd-networkd-wait-online.service

    # Optional filesystem mounts and automounts — not needed for minimal boot
    ln -sfv /dev/null etc/systemd/system/tmp.mount
    ln -sfv /dev/null etc/systemd/system/dev-mqueue.mount
    ln -sfv /dev/null etc/systemd/system/sys-kernel-debug.mount
    ln -sfv /dev/null etc/systemd/system/sys-kernel-config.mount
    ln -sfv /dev/null etc/systemd/system/proc-sys-fs-binfmt_misc.mount
    ln -sfv /dev/null etc/systemd/system/proc-sys-fs-binfmt_misc.automount

    # Sockets whose backing services are masked above
    ln -sfv /dev/null etc/systemd/system/systemd-networkd.socket
    ln -sfv /dev/null etc/systemd/system/systemd-networkd-varlink.socket
    ln -sfv /dev/null etc/systemd/system/systemd-networkd-varlink-metrics.socket
    ln -sfv /dev/null etc/systemd/system/systemd-networkd-resolve-hook.socket
    ln -sfv /dev/null etc/systemd/system/systemd-resolved-varlink.socket
    ln -sfv /dev/null etc/systemd/system/systemd-resolved-monitor.socket

    # On virt, there is no BOOT partition — mask boot.mount to avoid a 90 s device timeout
    if [ "${PLATFORM:-}" = virt ]; then
        ln -sfv /dev/null etc/systemd/system/boot.mount
    fi

    # Drop the IP firewall rules from journald — they require BPF/cgroup which we omit
    mkdir -pv etc/systemd/system/systemd-journald.service.d
    printf '[Service]\nIPAddressDeny=\nIPAddressAllow=\n' \
           > etc/systemd/system/systemd-journald.service.d/no-ip-firewall.conf

    # Preset file: instruct the first-boot preset to DISABLE all masked units
    # instead of trying to enable them (which would log "Failed to preset" errors)
    mkdir -pv etc/systemd/system-preset
    cat > etc/systemd/system-preset/80-lfs.preset << 'EOF'
disable systemd-logind.service
disable systemd-logind-varlink.socket
disable systemd-resolved.service
disable systemd-resolved-varlink.socket
disable systemd-resolved-monitor.socket
disable systemd-networkd.service
disable systemd-networkd.socket
disable systemd-networkd-varlink.socket
disable systemd-networkd-varlink-metrics.socket
disable systemd-networkd-resolve-hook.socket
disable systemd-networkd-wait-online.service
disable tmp.mount
disable dev-mqueue.mount
disable sys-kernel-debug.mount
disable sys-kernel-config.mount
disable proc-sys-fs-binfmt_misc.mount
disable proc-sys-fs-binfmt_misc.automount
EOF
    if [ "${PLATFORM:-}" = virt ]; then
        printf 'disable boot.mount\n' >> etc/systemd/system-preset/80-lfs.preset
    fi

    cat > etc/lsb-release <<EOF
DISTRIB_ID="Linux From Scratch"
DISTRIB_RELEASE="${DISTRIB_RELEASE:-local}"
DISTRIB_CODENAME="${DISTRIB_CODENAME:-local}"
DISTRIB_DESCRIPTION="Linux From Scratch"
EOF

    cat > etc/os-release <<EOF
NAME="Linux From Scratch"
VERSION="${LFS_RELEASE:-local}"
ID=lfs
PRETTY_NAME="Linux From Scratch${LFS_RELEASE:+ $LFS_RELEASE}"
VERSION_CODENAME="${VERSION_CODENAME:-local}"
HOME_URL="https://www.linuxfromscratch.org/lfs/"
RELEASE_TYPE="${RELEASE_TYPE:-development}"
EOF

    if [ -n "${LFS_RELEASE:-}" ]; then
        echo "$LFS_RELEASE" > etc/lfs-release
    fi
}
