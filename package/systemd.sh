: ${package_version:=260.2}
: ${package_source:=https://github.com/systemd/systemd/archive/v$package_version/systemd-$package_version.tar.gz}
: ${package_source_hash:=sha256:71a9ed11cf773478b0d7a16cd96e39ca3c3939ab37ed9a8ee814c31ea9b4f2b5}
: ${package_description:=System and service manager.}
: ${package_license:=LGPL-2.1-or-later AND GPL-2.0-or-later AND MIT AND BSD-3-Clause}

prepare() {
    case $package_component in
        systemd)
            # A build directory that meson configured earlier keeps its options and compilers:
            # setup leaves it alone, and ninja regenerates it with the old ones.
            find . -mindepth 1 -delete

            meson_cross_file

            # Pinned because meson would otherwise take them from the build machine: libdir (a
            # multiarch directory), split-bin (whether /usr/sbin is a symlink) and the system
            # UID/GID ranges (/etc/login.defs); the ranges match the login.defs that shadow
            # installs.
            # libmount, blkid and kmod are required rather than detected, so that a missing
            # library fails the build. logind would need a D-Bus system bus, and PAM to register
            # sessions.
            # Left out: the D-Bus services (hostnamed, localed, timedated), container and VM
            # management, the NSS modules, the hardware database (device names), journal transfer
            # over the network, desktop autostart, kernel-install, shell completions (no completion
            # framework is installed), and what needs kernel features (core dumps, pressure stall
            # information for oomd, pstore, hibernation, quotas) or hardware (backlights, rfkill,
            # virtual consoles, EFI) that these systems lack.
            # The journal stays in memory, which spares SD cards; creating /var/log/journal makes
            # it persistent.
            # The build scripts run through their `#!/usr/bin/env python3` shebang and need jinja2,
            # which the Python of TOOL_DIR has, unlike whichever python3 the build machine has
            # first in PATH. Meson, ninja and what they run all see the former first.
            env PATH=$TOOL_DIR/usr/bin:$PATH meson setup $package_source_dir \
                --cross-file cross.ini \
                ${prefix:+--prefix=$prefix} \
                --libdir=lib \
                --buildtype=release \
                -Dmode=release \
                -Dsplit-bin=true \
                -Dsystem-alloc-uid-min=101 \
                -Dsystem-uid-max=999 \
                -Dsystem-alloc-gid-min=101 \
                -Dsystem-gid-max=999 \
                -Dnobody-group=nogroup \
                -Ddev-kvm-mode=0660 \
                -Dman=disabled \
                -Dhtml=disabled \
                -Dtranslations=false \
                -Dtests=false \
                -Dpam=disabled \
                -Dpamconfdir=no \
                -Dfirstboot=false \
                -Dsysusers=false \
                -Dhomed=disabled \
                -Dlogind=false \
                -Duserdb=false \
                -Dldconfig=false \
                -Drpmmacrosdir=no \
                -Dukify=disabled \
                -Dbootloader=disabled \
                -Dsysupdate=disabled \
                -Drepart=disabled \
                -Dopenssl=disabled \
                -Dtpm2=disabled \
                -Dp11kit=disabled \
                -Dlibcryptsetup=disabled \
                -Dnetworkd=false \
                -Dresolve=false \
                -Dtimesyncd=true \
                -Dntp-servers= \
                -Dhostnamed=false \
                -Dlocaled=false \
                -Dtimedated=false \
                -Dmachined=false \
                -Dnspawn=disabled \
                -Dportabled=false \
                -Dimportd=disabled \
                -Dmountfsd=false \
                -Dnsresourced=false \
                -Dsysext=false \
                -Dstoragetm=false \
                -Dnss-myhostname=false \
                -Dnss-mymachines=disabled \
                -Dnss-resolve=disabled \
                -Dnss-systemd=false \
                -Dhwdb=false \
                -Dcoredump=false \
                -Doomd=false \
                -Dpstore=false \
                -Dhibernate=false \
                -Dquotacheck=false \
                -Dbacklight=false \
                -Drfkill=false \
                -Dvconsole=false \
                -Defi=false \
                -Dremote=disabled \
                -Dxdg-autostart=false \
                -Dkernel-install=false \
                -Dbashcompletiondir=no \
                -Dzshcompletiondir=no \
                -Djournal-storage-default=auto \
                -Dcreate-log-dirs=false \
                -Dkmod=enabled \
                -Dlibmount=enabled \
                -Dblkid=enabled
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        systemd)
            env PATH=$TOOL_DIR/usr/bin:$PATH ninja
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        systemd)
            DESTDIR=$package_install_dir env PATH=$TOOL_DIR/usr/bin:$PATH ninja install

            # Boards without a battery-backed clock start each boot at the date systemd was built.
            # timesyncd saves the clock every minute and on shutdown, and restores it at the next
            # boot. It has no NTP servers: without a network it only keeps the clock. Distributions
            # enable it with a preset; nothing here applies presets, so make the link that
            # `systemctl enable` makes from its [Install] section (the alias is for D-Bus
            # activation, which these systems lack).
            mkdir -pv $package_install_dir/etc/systemd/system/sysinit.target.wants
            ln -sv $prefix/lib/systemd/system/systemd-timesyncd.service \
                $package_install_dir/etc/systemd/system/sysinit.target.wants/

            # The default settings for what these kernels lack (SysRq, core dumps, an IPv4 stack)
            # fail at every boot. Only the file protections apply.
            cat > $package_install_dir$prefix/lib/sysctl.d/50-default.conf <<'EOF'
# systemd's own 50-default.conf, without the settings for what these kernels lack: SysRq, core
# dumps and an IPv4 stack. Applying them would fail at every boot.

# Enable hard and soft link protection
fs.protected_hardlinks = 1
fs.protected_symlinks = 1

# Enable regular file and FIFO protection
fs.protected_regular = 1
fs.protected_fifos = 1
EOF

            # X11's xinit script and socket directories are installed unconditionally; nothing here
            # uses X11.
            rm -rf $package_install_dir/etc/X11
            rm -v $package_install_dir$prefix/lib/tmpfiles.d/x11.conf

            # Images have an MBR partition table, which GPT auto-discovery does not apply to.
            local generators=$package_install_dir$prefix/lib/systemd/system-generators
            rm -v $generators/systemd-gpt-auto-generator

            # Empty directories for configuration and drop-ins (sysctl.d, system-shutdown...),
            # which systemd reads only when they exist: whoever adds a file creates its directory.
            find $package_install_dir -type d -empty -delete

            move_to_dev_component
            move_to_docs_component
            ;;
        dev)
            install_component
            ;;
        *)
            default_install
            ;;
    esac
}
