: ${package_version:=1.8.4}
: ${package_source:=https://ccid.apdu.fr/files/ccid-$package_version.tar.xz}
: ${package_source_hash:=sha256:4ff98151a7feb828a711e2f9d68c6b6065a97c597a81c2cbbd11d7f7edcfe743}
: ${package_description:=Driver for USB smart card readers, for pcscd.}
: ${package_license:=LGPL-2.1-or-later AND LGPL-2.0-or-later AND BSD-3-Clause AND ISC}
: ${package_cpe:=a:ccid_project:ccid:$package_version}

prepare() {
    case $package_component in
        ccid)
            # A build directory that meson configured earlier keeps its options and compilers:
            # setup leaves it alone, and ninja regenerates it with the old ones.
            find . -mindepth 1 -delete
            meson_cross_file

            # The driver goes where libpcsclite.pc says pcscd looks for drivers; see pcsc-lite for
            # why pkgconf follows freedesktop's rules. Only the readers that the driver lists by
            # their USB ids are supported: not any device of the CCID class, nor serial readers.
            # There are no udev rules, as root is the only user.
            env PKG_CONFIG_FDO_SYSROOT_RULES=1 meson setup $package_source_dir \
                --cross-file cross.ini \
                ${prefix:+--prefix=$prefix} \
                --libdir=lib \
                --buildtype=release \
                -Dclass=false \
                -Dserial=false \
                -Dzlp=false \
                -Dudev-rules=false
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        ccid)
            ninja
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        ccid)
            DESTDIR=$package_install_dir ninja install
            ;;
        *)
            default_install
            ;;
    esac
}
