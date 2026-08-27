# Opt-in "network" capability (CAPS=network): userspace side of
# package/linux/network.config's kernel bits — the actual DHCP client setup
# for each init flavor. Only ever require()d when CAPS contains "network"
# (see the bootable-*.sh umbrellas), so a build with CAPS unset installs
# none of this, matching a real network-less deployment.
: ${package_version:=0.1.0}

install() {
    cd $package_install_dir

    case $USERLAND in
        systemd)
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
            ;;

        busybox)
            # busybox-init.sh's rcS runs every executable /etc/init.d/S*
            # script after its own one-shot setup (a generic drop-in
            # mechanism added for this capability, usable by any future
            # one); this is the script this capability drops in.
            # -b: background immediately and keep retrying rather than
            # blocking boot if no DHCP server answers yet.
            mkdir -pv etc/init.d
            cat > etc/init.d/S40network <<'EOF'
#!/bin/sh
udhcpc -b -i eth0
EOF
            chmod -v 0755 etc/init.d/S40network

            # busybox's own `make install` does not install its udhcpc
            # sample script (examples/udhcp/simple.script in its source
            # tree) to /usr/share/udhcpc/default.script — udhcpc's
            # compiled-in default -s path. Without it, udhcpc obtains a
            # lease but never configures the interface or writes
            # resolv.conf. Installed verbatim, the same script busybox
            # itself ships as its standard example.
            mkdir -pv usr/share/udhcpc
            cat > usr/share/udhcpc/default.script <<'EOF'
#!/bin/sh
# udhcpc script edited by Tim Riker <Tim@Rikers.org>

RESOLV_CONF="/etc/resolv.conf"

[ -n "$1" ] || { echo "Error: should be called from udhcpc"; exit 1; }

NETMASK=""
if command -v ip >/dev/null; then
	[ -n "$subnet" ] && NETMASK="/$subnet"
else
	[ -n "$subnet" ] && NETMASK="netmask $subnet"
fi
BROADCAST="broadcast +"
[ -n "$broadcast" ] && BROADCAST="broadcast $broadcast"

case "$1" in
	deconfig)
		echo "Clearing IP addresses on $interface, upping it"
		if command -v ip >/dev/null; then
			ip -4 addr flush dev $interface
			ip link set dev $interface up
		else
			ifconfig $interface 0.0.0.0
		fi
		;;

	renew|bound)
		echo "Setting IP address $ip on $interface"
		if command -v ip >/dev/null; then
			ip addr add $ip$NETMASK $BROADCAST dev $interface
		else
			ifconfig $interface $ip $NETMASK $BROADCAST
		fi

		if [ -n "$router" ] ; then
			echo "Deleting routers"
			while route del default gw 0.0.0.0 dev $interface ; do
				:
			done

			metric=0
			for i in $router ; do
				echo "Adding router $i"
				if [ "$subnet" = "255.255.255.255" ]; then
	# special case for /32 subnets:
	# /32 instructs kernel to always use routing for all outgoing packets
	# (they can never be sent to local subnet - there is no local subnet for /32).
	# Used in datacenters, avoids the need for private ip-addresses between two hops.
					ip route add $i dev $interface
				fi
				route add default gw $i dev $interface metric $((metric++))
			done
		fi

		# If the file is a symlink somewhere (like /etc/resolv.conf
		# pointing to /run/resolv.conf), make sure things work.
		if test -L "$RESOLV_CONF"; then
			# If it's a dangling symlink, try to create the target.
			test -e "$RESOLV_CONF" || touch "$RESOLV_CONF"
		fi
		realconf=$(readlink -f "$RESOLV_CONF" 2>/dev/null || echo "$RESOLV_CONF")
		echo "Recreating $realconf"
		tmpfile="$realconf-$$"
		> "$tmpfile"
		[ -n "$domain" ] && echo "search $domain" >> "$tmpfile"
		for i in $dns ; do
			echo " Adding DNS server $i"
			echo "nameserver $i" >> "$tmpfile"
		done
		mv "$tmpfile" "$realconf"
		;;
esac

exit 0
EOF
            chmod -v 0755 usr/share/udhcpc/default.script
            ;;
    esac
}
