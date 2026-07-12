raspberrypi_kernel_source=https://github.com/raspberrypi/linux
torvalds_kernel_source=https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux

case $PLATFORM in
    pi0|pi1)
        : ${package_source:=$raspberrypi_kernel_source}
        : ${defconfig:=bcmrpi_defconfig}
        ;;
    pi4)
        : ${package_source:=$raspberrypi_kernel_source}
        : ${defconfig:=bcm2711_defconfig}
        ;;
    pi5)
        : ${package_source:=$raspberrypi_kernel_source}
        : ${defconfig:=bcm2712_defconfig}
        ;;
    *)
        : ${package_version:=7.1.2}
        local package_major_version="${package_version%%.*}"
        : ${package_source:=https://www.kernel.org/pub/linux/kernel/v$package_major_version.x/linux-$package_version.tar.xz}
        ;;
esac

prepare() {
    case $package_component in
        linux)
            case $PLATFORM in
                virt)
                    cat $package_files_dir/base.config \
                        $package_files_dir/virt.config \
                        $package_files_dir/$ARCH.config \
                        $package_files_dir/systemd.config \
                        > $package_source_dir/combined.config
                    _make KCONFIG_ALLCONFIG=$package_source_dir/combined.config allnoconfig
                    ;;
                *)
                    _make $defconfig
                    ;;
            esac
            ${MACHINE:+_set_kernel_config DEFAULT_HOSTNAME "$MACHINE"}
            ${PLATFORM:+_set_kernel_config LOCALVERSION "-$PLATFORM"}
            _make olddefconfig
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        headers)
            _make headers
            ;;
        linux)
            case $ARCH in
                arm)   _make zImage modules ${DTB:+dtbs} ;;
                arm64) _make Image modules ${DTB:+dtbs} ;;
                *)     _make Image modules ;;
            esac
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        headers)
            _make INSTALL_HDR_PATH=$package_install_dir/usr headers_install
            ;;
        linux)
            _make \
                INSTALL_DTBS_PATH=$package_install_dir/boot \
                INSTALL_MOD_PATH=$package_install_dir \
                ${DTB:+dtbs_install} modules_install
            mkdir -pv $package_install_dir/boot
            # Install kernel image with a consistent name for QEMU and real hardware
            case $ARCH in
                arm)
                    cp -v $package_source_dir/arch/arm/boot/zImage \
                        $package_install_dir/boot/kernel.img
                    ;;
                arm64)
                    cp -v $package_source_dir/arch/arm64/boot/Image \
                        $package_install_dir/boot/kernel.img
                    ;;
            esac
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
    sed -i 's/CONFIG_'"$key"'="[^"]*"/CONFIG_'"$key"'="'"$value"'"/g' \
        $package_source_dir/.config
}
