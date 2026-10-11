: ${package_version:=260.2}
: ${package_source:=https://github.com/systemd/systemd/archive/v$package_version/systemd-$package_version.tar.gz}
: ${package_source_hash:=sha256:71a9ed11cf773478b0d7a16cd96e39ca3c3939ab37ed9a8ee814c31ea9b4f2b5}
: ${package_description:=System and service manager.}
: ${package_license:=LGPL-2.1-or-later AND GPL-2.0-or-later AND MIT AND BSD-3-Clause}

prepare() {
    case $package_component in
        systemd)
            cat > cross.ini <<EOF
[host_machine]
system = 'linux'
cpu_family = '$target_arch'
cpu = '$target_arch'
endian = 'little'

[binaries]
c = '$host-gcc'
cpp = '$host-g++'
ar = '$host-ar'
strip = '$host-strip'
pkg-config = 'pkg-config'

[properties]
sys_root = '$sysroot'
pkg_config_libdir = ['$sysroot/usr/lib/pkgconfig', '$sysroot/usr/share/pkgconfig']
EOF

            # Pinned because meson would otherwise take them from the build machine: libdir (a
            # multiarch directory), split-bin (whether /usr/sbin is a symlink) and the system
            # UID/GID ranges (/etc/login.defs); the ranges match the login.defs that shadow
            # installs.
            # libmount, blkid and kmod are required rather than detected, so that a missing
            # library fails the build. logind would need a D-Bus system bus, and PAM to register
            # sessions.
            meson setup $package_source_dir \
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
                -Dtimesyncd=false \
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
            ninja
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        systemd)
            DESTDIR=$package_install_dir ninja install

            # An xinit script is installed unconditionally; nothing here uses X11.
            rm -rf $package_install_dir/etc/X11

            # Images have an MBR partition table, which GPT auto-discovery does not apply to.
            local generators=$package_install_dir$prefix/lib/systemd/system-generators
            rm -v $generators/systemd-gpt-auto-generator

            split_dev_files
            split_debug_info
            ;;
        dev|debug)
            install_split
            ;;
        *)
            default_install
            ;;
    esac
}
