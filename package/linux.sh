# Raspberry Pi kernel: a pinned branch fetched as a GitHub *tarball* (via
# wget), NOT a git clone. The scratch container that runs the system phase
# has no git, and a pinned tarball is reproducible where tracking a moving
# default branch isn't. A github URL ending in .tar.gz matches the plain
# wget/tar fetch path (checked before the git path in lib/package.sh), and
# GitHub extracts refs/heads/$b.tar.gz to linux-$b/ — so setting
# package_version=$raspberrypi_kernel_branch makes package_source_dir
# (=$SOURCE_DIR/linux-$package_version) line up exactly. Bump deliberately.
raspberrypi_kernel_branch=rpi-6.18.y
# archive/<ref>/<name>.tar.gz form so the download is named linux-<branch>.tar.gz
# (matching the dir GitHub extracts to, = package_source_dir below) rather than
# a bare <branch>.tar.gz — see kpartx.sh for the full rationale.
raspberrypi_kernel_source=https://github.com/raspberrypi/linux/archive/refs/heads/$raspberrypi_kernel_branch/linux-$raspberrypi_kernel_branch.tar.gz

if [ "${package_component:-}" = headers ]; then
    # The toolchain's glibc (the shared native one and every per-target
    # sysroot) needs only ABI-generic kernel headers, so the 'headers'
    # component always comes from a plain mainline tarball — never a
    # platform's downstream kernel. Pinning the shared toolchain to one
    # platform's kernel would be wrong regardless. Only the actual bootable
    # kernel (component 'linux', built in the system phase) uses the
    # platform-specific source below.
    : ${package_version:=7.1.2}
    local package_major_version="${package_version%%.*}"
    : ${package_source:=https://www.kernel.org/pub/linux/kernel/v$package_major_version.x/linux-$package_version.tar.xz}
else
    case $PLATFORM in
        pi0|pi1)
            : ${package_version:=$raspberrypi_kernel_branch}
            : ${package_source:=$raspberrypi_kernel_source}
            : ${defconfig:=bcmrpi_defconfig}
            ;;
        pi4)
            : ${package_version:=$raspberrypi_kernel_branch}
            : ${package_source:=$raspberrypi_kernel_source}
            : ${defconfig:=bcm2711_defconfig}
            ;;
        pi5)
            : ${package_version:=$raspberrypi_kernel_branch}
            : ${package_source:=$raspberrypi_kernel_source}
            : ${defconfig:=bcm2712_defconfig}
            ;;
        *)
            : ${package_version:=7.1.2}
            local package_major_version="${package_version%%.*}"
            : ${package_source:=https://www.kernel.org/pub/linux/kernel/v$package_major_version.x/linux-$package_version.tar.xz}
            ;;
    esac
fi

prepare() {
    case $package_component in
        linux)
            # Assemble a minimal kernel from allnoconfig + config fragments
            # whenever the platform ships its own machine config (base +
            # <platform> + <arch> + systemd). Each <platform>.config is
            # self-contained — virt.config, pi0.config, pi4.config each carry
            # everything their machine needs (no shared "pi" layer, so the
            # Pi 0's config is never mixed into the Pi 4's). This keeps every
            # emulated target small and fast and avoids the downstream
            # defconfig's mass of drivers for hardware QEMU doesn't model.
            # base.config supplies btrfs (=y, our root fs — the Pi defconfigs
            # only build it as a module). Platforms without a machine config
            # fall back to their full defconfig.
            if [ -f "$package_files_dir/$PLATFORM.config" ]; then
                cat $package_files_dir/base.config \
                    $package_files_dir/$PLATFORM.config \
                    $package_files_dir/$ARCH.config \
                    $package_files_dir/systemd.config \
                    > $package_source_dir/combined.config
                _make KCONFIG_ALLCONFIG=$package_source_dir/combined.config allnoconfig
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
            # modules_install runs depmod (module.dep/modules.alias/etc —
            # without them modprobe/systemd can't resolve a module by name
            # even though the .ko file is right there on disk) as a matter
            # of course, via scripts/depmod.sh, *if* it can find a depmod on
            # PATH — tools_build builds one into TOOL_DIR for exactly this
            # (build-host-native: depmod only reads the target's .ko files,
            # it doesn't need to run on the target itself).
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
