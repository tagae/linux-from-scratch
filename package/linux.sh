case $PLATFORM in
    pi0|pi4|pi5)
        package_version=stable_20260609 # 6.18.34
        package_source=https://github.com/raspberrypi/linux/archive/refs/tags/$package_version/linux-$package_version.tar.gz
        package_source_hash=sha256:3eacbbb1253a913034efd38ce6aeee2def137eb40c799af2745db874796e389d
        ;;
    *)
        package_version=7.1.2
        package_source=https://www.kernel.org/pub/linux/kernel/v${package_version%%.*}.x/linux-$package_version.tar.xz
        package_source_hash=sha256:37198c93727be247c9fb5309bb86cd5e496c61e5322cd8c4eca9476bb0b5883f
        ;;
esac

prepare() {
    case $package_component in
        linux)
            if [ -f "$package_files_dir/$PLATFORM.config" ]; then
                {
                    cat $package_files_dir/base.config \
                        $package_files_dir/$PLATFORM.config \
                        ${arch:+$package_files_dir/$arch.config} \
                        $package_files_dir/$USERLAND.config
                    for cap in $CAPS; do
                        [ -f $PROJECT_DIR/package/linux/$cap.config ] \
                            || bail "Unknown capability '$cap' (no package/linux/$cap.config)"
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
            case $arch in
                arm) _make zImage modules ${dev_tree_blob:+dtbs} ;;
                *) _make Image modules ${dev_tree_blob:+dtbs} ;;
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
                ${dev_tree_blob:+dtbs_install} modules_install
            mkdir -pv $package_install_dir/boot
            cp -v $package_source_dir/arch/$kernel_arch/boot/zImage \
               $package_install_dir/boot/kernel.img
            ;;
        *)
            default_install
            ;;
    esac
}

_make() {
    make -C $package_source_dir \
         ${arch:+ARCH=$arch} ${target_triple:+CROSS_COMPILE=$target_triple-} "$@"
}

_set_kernel_config() {
    local key="$1" value="$2"
    sed -i 's/CONFIG_'"$key"'="[^"]*"/CONFIG_'"$key"'="'"$value"'"/g' $package_source_dir/.config
}
