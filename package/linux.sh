case $PLATFORM in
    pi0)
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

# Where the kernel builds its image, whose name is also the make target for it.
case $kernel_arch in
    arm)    kernel_image=arch/arm/boot/zImage ;;
    arm64)  kernel_image=arch/arm64/boot/Image ;;
    x86_64) kernel_image=arch/x86/boot/bzImage ;;
    *)      bail "Unsupported kernel architecture '$kernel_arch'" ;;
esac

: ${package_description:=Linux kernel.}
: ${package_license:=GPL-2.0-only WITH Linux-syscall-note}

prepare() {
    case $package_component in
        linux)
            # A platform with no configuration fragment for its machine builds its defconfig.
            if [ -n "${kernel_machine:-}" ]; then
                {
                    cat $package_files_dir/base.config \
                        $package_files_dir/hardening.config \
                        $package_files_dir/$kernel_machine.config \
                        $package_files_dir/arch-$kernel_arch.config \
                        $package_files_dir/$USERLAND.config
                    # A capability that needs kernel support has a fragment of its own.
                    for cap in $CAPS; do
                        [ ! -f $package_files_dir/$cap.config ] || cat $package_files_dir/$cap.config
                    done
                } > $package_build_dir/$package_name.config
                _make_target KCONFIG_ALLCONFIG=$package_build_dir/$package_name.config allnoconfig
            else
                _make_target $defconfig
            fi
            ${MACHINE:+_set_kernel_config DEFAULT_HOSTNAME "$MACHINE"}
            ${PLATFORM:+_set_kernel_config LOCALVERSION "-$PLATFORM"}
            _make_target olddefconfig
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        headers)
            _make_headers headers
            ;;
        linux)
            _make_target ${kernel_image##*/} modules ${dev_tree_blob:-}
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        headers)
            _make_headers INSTALL_HDR_PATH=$package_install_dir/usr headers_install
            ;;
        linux)
            # modules_install writes to lib/modules/ -not configurable.
            # Symlink it so that writes go to usr/lib instead.
            mkdir -p $package_install_dir/usr/lib
            ln -sfn usr/lib $package_install_dir/lib

            # modules_install runs depmod *if* it can find a depmod on PATH.
            _make_target INSTALL_MOD_PATH=$package_install_dir modules_install
            mkdir -pv $package_install_dir/boot
            cp -v $package_build_dir/$kernel_image \
               $package_install_dir/boot/kernel.img

            # The platform's own device tree, rather than those of every board of its SoC family,
            # next to the kernel, where the Raspberry Pi firmware looks for it.
            if [ -n "${dev_tree_blob:-}" ]; then
                cp -v $package_build_dir/${kernel_image%/*}/dts/$dev_tree_blob \
                   $package_install_dir/boot/
            fi
            ;;
        *)
            default_install
            ;;
    esac
}

_make() {
    make -C $package_source_dir O=$package_build_dir "$@"
}

# Headers describe the kernel interface to the libc of the host: the platform's when compiling for
# it, the build machine's otherwise.
_make_headers() {
    _make ${host:+ARCH=$kernel_arch} "$@"
}

# Builds for the platform's architecture.
_make_target() {
    _make ARCH=$kernel_arch ${target_triplet:+CROSS_COMPILE=$target_triplet-} "$@"
}

_set_kernel_config() {
    local key="$1" value="$2"
    sed -i 's/CONFIG_'"$key"'="[^"]*"/CONFIG_'"$key"'="'"$value"'"/g' $package_build_dir/.config
}
