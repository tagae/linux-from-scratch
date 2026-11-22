: ${package_version:=1.16.4}
: ${package_source:=https://dbus.freedesktop.org/releases/dbus/dbus-$package_version.tar.xz}
: ${package_source_hash:=sha256:d08b05526c2cb7966a5fb79210d6112b1aca3d135f315c1b302e14b4b0297dac}
: ${package_description:=Message bus system, for programs to talk to each other.}
: ${package_license:=GPL-2.0-or-later AND (AFL-2.1 OR GPL-2.0-or-later) AND MIT AND TCL AND LicenseRef-pycrypto-orig}
: ${package_cpe:=a:freedesktop:dbus:$package_version}

prepare() {
    case $package_component in
        dbus)
            # A build directory that meson configured earlier keeps its options and compilers:
            # setup leaves it alone, and ninja regenerates it with the old ones.
            find . -mindepth 1 -delete
            meson_cross_file

            # pkgconf puts the sysroot in front of every absolute path in a .pc file, unless told
            # to follow freedesktop's rules, where only flags get it. Meson reads systemd.pc's
            # unit directories as install directories, which would otherwise land in a copy of the
            # sysroot's path under the staging directory.
            # systemd starts the bus from its socket, and starts the services that the bus
            # activates: the daemon has no setuid helper to start them. There is no session bus,
            # which needs a login session, no security module and no audit, no X11, and the
            # regression tests need GLib.
            env PKG_CONFIG_FDO_SYSROOT_RULES=1 meson setup $package_source_dir \
                --cross-file cross.ini \
                ${prefix:+--prefix=$prefix} \
                --libdir=lib \
                --buildtype=release \
                -Dsystemd=enabled \
                -Dtraditional_activation=false \
                -Duser_session=false \
                -Depoll=enabled \
                -Dinotify=enabled \
                -Dapparmor=disabled \
                -Dselinux=disabled \
                -Dlibaudit=disabled \
                -Dx11_autolaunch=disabled \
                -Dmodular_tests=disabled \
                -Ddoxygen_docs=disabled \
                -Dducktype_docs=disabled \
                -Dxml_docs=disabled \
                -Dqt_help=disabled
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        dbus)
            ninja
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        dbus)
            DESTDIR=$package_install_dir ninja install
            cd $package_install_dir
            cp -rv $package_files_dir/usr .

            # Upstream links its units into the target directories under /usr/lib, which read as
            # "disabled" to `systemctl is-enabled`. Nothing here applies presets, so make the links
            # that `systemctl enable` makes from the [Install] sections. The account of the bus,
            # messagebus, is one of the static ones: nothing creates users from sysusers.d.
            rm -rv usr/lib/systemd/system/multi-user.target.wants \
                usr/lib/systemd/system/sockets.target.wants \
                usr/lib/sysusers.d
            mkdir -pv etc/systemd/system/multi-user.target.wants \
                etc/systemd/system/sockets.target.wants
            ln -sv $prefix/lib/systemd/system/dbus.service etc/systemd/system/multi-user.target.wants/
            ln -sv $prefix/lib/systemd/system/dbus.socket etc/systemd/system/sockets.target.wants/

            # There is no session bus: its tools and configuration, and the DTD for writing
            # configuration files, stay out.
            rm -rv usr/bin/dbus-cleanup-sockets usr/bin/dbus-launch usr/bin/dbus-run-session \
                usr/bin/dbus-test-tool usr/bin/dbus-update-activation-environment \
                etc/dbus-1/session.conf usr/share/dbus-1/session.conf usr/share/xml

            # The directories for configuration and services that others add to stay out until
            # they do.
            find . -type d -empty -delete

            move_to_dev_component usr/lib/cmake usr/lib/dbus-1.0
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
