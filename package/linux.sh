case $PLATFORM in
    pi0)
        package_version=stable_20261103 # 6.18.60
        package_source=https://github.com/raspberrypi/linux/archive/refs/tags/$package_version/linux-$package_version.tar.gz
        package_source_hash=sha256:53a3967359cf1b68953bbfc5aef5d3c7fcf9ebf61518fbba108c6a8bfce0c079
        ;;
    *)
        package_version=7.3.1
        package_source=https://www.kernel.org/pub/linux/kernel/v${package_version%%.*}.x/linux-$package_version.tar.xz
        package_source_hash=sha256:fa595aad93734f829c963c2a90ef7c3673224fd7fdae7b49406e397cde2de231
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
            # Overrides of the platform's board file: a host-only USB controller, and no SD write-protect
            # switch.
            if [ -n "${dev_tree_blob:-}" ]; then
                local board=${dev_tree_blob##*/}
                apply_patch $package_files_dir/${board%.dtb}.patch
            fi

            # A platform with no configuration fragment for its machine builds its defconfig.
            # The others add the optional fragments listed in `fragments` to the layers that every
            # system gets, the userland's included.
            if [ -n "${kernel_machine:-}" ]; then
                local fragment
                {
                    cat $package_files_dir/base.config \
                        $package_files_dir/hardening.config \
                        $package_files_dir/$kernel_machine.config \
                        $package_files_dir/$kernel_arch.config \
                        $package_files_dir/$USERLAND.config
                    for fragment in ${fragments:-}; do
                        cat $package_files_dir/$fragment.config
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
