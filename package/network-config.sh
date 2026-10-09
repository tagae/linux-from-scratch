# Opt-in "network" capability (CAPS=network): userspace side of
# package/linux/network.config's kernel bits — the DHCP client setup.
# Installed only when CAPS contains "network".
: ${package_version:=0.1.0}

install() {
    cd $package_install_dir

    # package/systemd.sh's install() masks systemd-networkd with
    # /dev/null symlinks by default — but skips exactly those two
    # masks (the service and its netlink socket) itself when CAPS
    # contains network. The skip must live THERE, not here: merge
    # is additive-only (a package's tarball can add or overwrite
    # paths, never delete what an earlier package merged), so an
    # rm in this stage dir would be a silent no-op. This package
    # only ADDS: the enable symlink and the DHCP config below.
    # wait-online and the varlink/resolve-hook sockets stay masked
    # even with networking (not needed for a lease; wait-online
    # would gate boot on network availability); systemd-resolved
    # stays masked too (see resolv.conf below).

    # No working `systemctl enable` at build time (no PID 1 running
    # here to ask) — wants-symlinks are the simplest robust way to
    # actually enable units. systemd.sh's own 80-lfs.preset file
    # still says "disable" for these, but that only matters to an
    # explicit `systemctl preset-all`, which nothing in this build
    # ever runs.
    mkdir -pv etc/systemd/system/multi-user.target.wants
    ln -sfv /usr/lib/systemd/system/systemd-networkd.service \
        etc/systemd/system/multi-user.target.wants/systemd-networkd.service
    ln -sfv /usr/lib/systemd/system/systemd-resolved.service \
        etc/systemd/system/multi-user.target.wants/systemd-resolved.service

    # MulticastDNS= must be set in BOTH places to be live on an
    # interface: resolved.conf's [Resolve] switches the global
    # capability on, and networkd's per-link [Network] setting
    # opts each link in — either alone leaves mDNS off.
    mkdir -pv etc/systemd/network
    cat > etc/systemd/network/20-dhcp.network <<'EOF'
[Match]
Name=en* eth*

[Network]
DHCP=yes
MulticastDNS=yes
EOF

    # systemd-resolved is unmasked (above) and enabled: DNS servers
    # come from DHCP via networkd (correct on QEMU slirp AND real
    # hardware — no hardcoded server), and mDNS resolves/announces
    # .local names on all interfaces. DNSSEC is off in resolved's
    # build defaults (systemd.sh: -Ddefault-dnssec=no).
    mkdir -pv etc/systemd/resolved.conf.d
    cat > etc/systemd/resolved.conf.d/10-mdns.conf <<'EOF'
[Resolve]
MulticastDNS=yes
EOF

    # Glibc's resolver reads /etc/resolv.conf; point it at
    # resolved's stub (127.0.0.53), which forwards to the
    # DHCP-provided servers and routes .local to mDNS. The target
    # lives under /run (tmpfs, written by resolved at runtime), so
    # this also works unchanged on an amnesia (read-only-root)
    # system.
    ln -sfv /run/systemd/resolve/stub-resolv.conf etc/resolv.conf
}
