# Opt-in "network" capability (CAPS=network): userspace side of
# package/linux/network.config's kernel bits — the actual DHCP client setup
# for each init flavor. Only ever require()d when CAPS contains "network"
# (see the bootable-*.sh umbrellas), so a build with CAPS unset installs
# none of this, matching a real network-less deployment.
: ${package_version:=0.1.0}

install() {
    cd $package_install_dir

    case $INIT in
        systemd)
            # package/systemd.sh's install() masks systemd-networkd (and
            # systemd-resolved) with /dev/null symlinks — this minimal
            # build has no network by default. Reverse only what a DHCP
            # lease actually needs: the service itself and its own netlink
            # socket (named in the unit's own Sockets=). The varlink
            # management sockets, the resolve-hook socket, and
            # systemd-networkd-wait-online.service all stay masked — none
            # of them are needed to bring an interface up, and wait-online
            # would gate boot on network availability, which this minimal
            # serial-console system never wants. systemd-resolved also
            # stays masked (see resolv.conf below).
            rm -fv etc/systemd/system/systemd-networkd.service
            rm -fv etc/systemd/system/systemd-networkd.socket

            # No working `systemctl enable` at build time (no PID 1 running
            # here to ask) — a wants-symlink is the simplest robust way to
            # actually enable the unit. systemd.sh's own 80-lfs.preset file
            # still says "disable" for these two units, but that only
            # matters to an explicit `systemctl preset-all`, which nothing
            # in this build ever runs.
            mkdir -pv etc/systemd/system/multi-user.target.wants
            ln -sfv /usr/lib/systemd/system/systemd-networkd.service \
                etc/systemd/system/multi-user.target.wants/systemd-networkd.service

            mkdir -pv etc/systemd/network
            cat > etc/systemd/network/20-dhcp.network <<'EOF'
[Match]
Name=en* eth*

[Network]
DHCP=yes
EOF

            # systemd-resolved stays masked (above), so there's no stub
            # resolver to point at. A static resolv.conf is the pragmatic
            # answer for QEMU's user-mode ("slirp") network backend, whose
            # built-in DNS proxy always lives at 10.0.2.3. Real hardware
            # (once a NIC driver exists — see network.config) will want
            # DNS servers from DHCP instead; future work alongside those
            # drivers.
            cat > etc/resolv.conf <<'EOF'
nameserver 10.0.2.3
EOF
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
