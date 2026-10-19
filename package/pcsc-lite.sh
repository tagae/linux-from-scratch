: ${package_version:=2.5.3}
: ${package_source:=https://pcsclite.apdu.fr/files/pcsc-lite-$package_version.tar.xz}
: ${package_source_hash:=sha256:fe2bb733ecf95e52768907eb00da9f9f3daf180960283e514a05dcc090afa3bd}
: ${package_description:=Daemon and library to use smart card readers.}
: ${package_license:=BSD-3-Clause AND ISC}

prepare() {
    case $package_component in
        pcsc-lite)
            # A build directory that meson configured earlier keeps its options and compilers:
            # setup leaves it alone, and ninja regenerates it with the old ones.
            find . -mindepth 1 -delete
            meson_cross_file

            # pkgconf puts the sysroot in front of every absolute path in a .pc file, unless told
            # to follow freedesktop's rules, where only flags get it. Meson reads systemd.pc's
            # unit directory as an install directory, which would otherwise land in a copy of the
            # sysroot's path under the staging directory.
            # Hotplug comes from udev's netlink events, instead of from polling the bus once a
            # second, and the socket from systemd, which starts the daemon on demand. Readers are
            # USB only, and nothing enforces access control: root is the only user.
            env PKG_CONFIG_FDO_SYSROOT_RULES=1 meson setup $package_source_dir \
                --cross-file cross.ini \
                ${prefix:+--prefix=$prefix} \
                --libdir=lib \
                --buildtype=release \
                -Dlibudev=true \
                -Dlibsystemd=true \
                -Dpolkit=false \
                -Dusb=true \
                -Dserial=false \
                -Dlibusb=false \
                -Dsystemdunit=system
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        pcsc-lite)
            ninja
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        pcsc-lite)
            DESTDIR=$package_install_dir ninja install
            cd $package_install_dir

            # Upstream's units run the daemon as a pcscd user and in sandboxes that these kernels
            # lack (user namespaces, seccomp), and these systems have no such user. The socket is
            # root's, as the daemon is: it creates /run/pcscd, and the service starts when a program
            # connects to it. Distributions enable units with a preset; nothing here applies
            # presets, so make the link that `systemctl enable` makes from the [Install] section.
            cp -rv $package_files_dir/usr .
            mkdir -pv etc/systemd/system/sockets.target.wants
            ln -sv $prefix/lib/systemd/system/pcscd.socket etc/systemd/system/sockets.target.wants/

            # The tracer is GPL-3.0 and of no use here. What is left of upstream's units: the
            # daemon's environment file (read by its unit only), the account of its user, and the
            # AppStream metadata.
            rm -v usr/lib/libpcscspy.so* usr/bin/pcsc-spy
            rm -rv etc/default usr/lib/sysusers.d usr/share/metainfo
            find . -type d -empty -delete

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
