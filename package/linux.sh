raspberrypi_kernel_source=https://github.com/raspberrypi/linux
torvalds_kernel_source=https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux

case $PLATFORM in
    pi0)
        : ${package_source:=$raspberrypi_kernel_source}
        : ${defconfig=bcmrpi_defconfig}
        ;;
    *)
        : ${package_source:=$torvalds_kernel_source}
        ;;
esac

prepare() {
    case $package_component in
        linux)
            _make ${KCONFIG_ALLCONFIG:+KCONFIG_ALLCONFIG=$KCONFIG_ALLCONFIG allnoconfig} bcmrpi_defconfig menuconfig
            ${MACHINE:+_set_kernel_config DEFAULT_HOSTNAME $MACHINE}
            ${PLATFORM:+_set_kernel_config LOCALVERSION -$PLATFORM}
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        linux)
            _make Image modules dtbs
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        headers)
            _make INSTALL_HDR_PATH=$package_install_dir headers_install
            ;;
        linux)
            _make \
                INSTALL_PATH=$package_install_dir/boot \
                INSTALL_DTBS_PATH=$package_install_dir/boot \
                INSTALL_MOD_PATH=$package_install_dir \
                install dtbs_install modules_install
            ;;
        cmdline)
            echo > $package_install_dir/boot/cmdline.txt \
                 console=serial0,115200 \
                 root=LABEL=base rootfstype=btrfs rootflags=subvol=system/$ROOT_VOLUME \
                 rootwait
            ;;
        *)
            default_install
            ;;
    esac
}

_make() {
    make -C $package_source_dir ARCH=$ARCH CROSS_COMPILE=$target- "$@"
}

_set_kernel_config() {
    local key="$1" value="$2"
    sed -i 's/CONFIG_'$key'="[^"]*"/CONFIG_'$key'="'"$value"'"/g' $package_source_dir/.config
}
