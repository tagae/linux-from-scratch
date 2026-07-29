: ${package_version:=7.1.2}
: ${package_source:=https://www.kernel.org/pub/linux/kernel/v${package_version%%.*}.x/linux-$package_version.tar.xz}
: ${package_source_hash:=sha256:37198c93727be247c9fb5309bb86cd5e496c61e5322cd8c4eca9476bb0b5883f}

: ${raspberrypi_kernel_tag:=stable_20260609} # 6.18.34
: ${raspberrypi_kernel_source:=https://github.com/raspberrypi/linux/archive/refs/tags/$raspberrypi_kernel_tag/linux-$raspberrypi_kernel_tag.tar.gz}
: ${raspberrypi_kernel_source_hash:=sha256:3eacbbb1253a913034efd38ce6aeee2def137eb40c799af2745db874796e389d}

case $PLATFORM in
    pi0)
        package_version=$raspberrypi_kernel_tag
        package_source=$raspberrypi_kernel_source
        package_source_hash=$raspberrypi_kernel_source_hash
        defconfig=bcmrpi_defconfig
        ;;
    pi4)
        package_version=$raspberrypi_kernel_tag
        package_source=$raspberrypi_kernel_source
        package_source_hash=$raspberrypi_kernel_source_hash
        defconfig=bcm2711_defconfig
        ;;
    pi5)
        package_version=$raspberrypi_kernel_tag
        package_source=$raspberrypi_kernel_source
        package_source_hash=$raspberrypi_kernel_source_hash
        defconfig=bcm2712_defconfig
        ;;
esac

prepare() {
    case $package_component in
        linux)
            if [ -f "$package_files_dir/$PLATFORM.config" ]; then
                {
                    cat $package_files_dir/base.config \
                        $package_files_dir/$PLATFORM.config \
                        $package_files_dir/$ARCH.config \
                        $package_files_dir/$USERLAND.config
                    for cap in $CAPS; do
                        [ -f $PROJECT_DIR/package/linux/$cap.config ] || bail "Unknown capability '$cap' (no package/linux/$cap.config)"
                    done
                    for cap in ${CAPS:-}; do
                        cat $package_files_dir/$cap.config
                    done
                } > $package_build_dir/$package_name.config
                _make KCONFIG_ALLCONFIG=$package_build_dir/$package_name.config allnoconfig
            else
                _make $defconfig
            fi
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
                arm) _make zImage modules ${DTB:+dtbs} ;;
                *) _make Image modules ${DTB:+dtbs} ;;
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
            # modules_install writes to lib/modules/ -not configurable.
            # Symlink it so that writes go to usr/lib instead.
            mkdir -p $package_install_dir/usr/lib
            ln -sfn usr/lib $package_install_dir/lib

            # modules_install runs depmod *if* it can find a depmod on PATH.
            _make \
                INSTALL_DTBS_PATH=$package_install_dir/boot \
                INSTALL_MOD_PATH=$package_install_dir \
                ${DTB:+dtbs_install} modules_install
            mkdir -pv $package_install_dir/boot
            # Install kernel image with a consistent name.
            cp -v $package_source_dir/arch/$$ARCH/boot/zImage \
               $package_install_dir/boot/kernel.img
            ;;
        *)
            default_install
            ;;
    esac
}

_make() {
    # cross_arch defaults to $ARCH (the platform's real target architecture
    # — every existing caller keeps working unchanged), but the build-host-
    # native toolchain's own kernel headers (needed to build a glibc that
    # runs *in the scratch container*, as opposed to the per-platform
    # target sysroot's headers) need the build host's own architecture
    # instead — genuinely different from $ARCH for pi0 (32-bit ARM) on an
    # aarch64 build host. $ARCH itself is globally readonly and can't be
    # reassigned even via a prefix assignment, hence this separate var.
    : ${cross_arch:=$ARCH}
    make -C $package_source_dir ARCH=$cross_arch CROSS_COMPILE=$target- "$@"
}

_set_kernel_config() {
    local key="$1" value="$2"
    sed -i 's/CONFIG_'"$key"'="[^"]*"/CONFIG_'"$key"'="'"$value"'"/g' \
        $package_source_dir/.config
}
