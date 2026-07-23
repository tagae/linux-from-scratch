# Raspberry Pi kernel: a pinned release *tag* fetched as a GitHub tarball
# (via wget), NOT a git clone (the scratch container that runs the system
# phase has no git) and NOT a branch tarball: a branch head moves, so its
# archive's bytes change out from under the sha256 pin (bit us in practice —
# the pin correctly rejected a re-rolled rpi-6.18.y tarball). raspberrypi/
# linux's stable_YYYYMMDD tags are their fixed release points; a tag
# archive's content is stable, so the pin stays valid until deliberately
# bumped. A github URL ending in .tar.gz matches the plain wget/tar fetch
# path (checked before the git path in lib/package.sh), and GitHub extracts
# refs/tags/$t.tar.gz to linux-$t/ — so setting package_version=$tag makes
# package_source_dir (=$SOURCE_DIR/linux-$package_version) line up exactly.
#
# stable_20260609 = the rpi-6.18.y line (6.18.34 at that point), shared by
# every Pi platform. pi0/pi1 briefly needed a 6.6-line pin: 6.18's
# bcm2835-sdhost driver hits a raspberrypi/linux MMIO-DMA regression
# (phys_to_dma() on the SD controller's own register address returns a
# bogus sentinel, so every DMA-driven SD read fails → "VFS: Unable to
# mount root fs"; see raspberrypi/linux#7136 — invisible on pi4/pi5, whose
# sdhci-iproc/emmc2 never touches bcm2835-dma). That pin is retired:
# pi0.config drops CONFIG_DMADEVICES entirely (originally for QEMU's own
# incomplete bcm2835-dma SD emulation, see there), which makes the sdhost
# driver fall back to PIO and never execute the regressed DMA path at all —
# retested on this 6.18.34 tag, both init flavors boot cleanly.
raspberrypi_kernel_tag=stable_20260609

# archive/<ref>/<name>.tar.gz form so the download is named linux-<tag>.tar.gz
# (matching the dir GitHub extracts to, = package_source_dir below) rather than
# a bare <tag>.tar.gz — see multipath-tools.sh for the full rationale.
_raspberrypi_kernel_source() {
    echo "https://github.com/raspberrypi/linux/archive/refs/tags/$1/linux-$1.tar.gz"
}

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
    : ${package_source_hash:=sha256:37198c93727be247c9fb5309bb86cd5e496c61e5322cd8c4eca9476bb0b5883f}
else
    case $PLATFORM in
        pi0|pi1)
            : ${package_version:=$raspberrypi_kernel_tag}
            : ${package_source:=$(_raspberrypi_kernel_source $raspberrypi_kernel_tag)}
            : ${package_source_hash:=sha256:3eacbbb1253a913034efd38ce6aeee2def137eb40c799af2745db874796e389d}
            : ${defconfig:=bcmrpi_defconfig}
            ;;
        pi4)
            : ${package_version:=$raspberrypi_kernel_tag}
            : ${package_source:=$(_raspberrypi_kernel_source $raspberrypi_kernel_tag)}
            : ${package_source_hash:=sha256:3eacbbb1253a913034efd38ce6aeee2def137eb40c799af2745db874796e389d}
            : ${defconfig:=bcm2711_defconfig}
            ;;
        pi5)
            : ${package_version:=$raspberrypi_kernel_tag}
            : ${package_source:=$(_raspberrypi_kernel_source $raspberrypi_kernel_tag)}
            # Same tag tarball as pi4 above.
            : ${package_source_hash:=sha256:3eacbbb1253a913034efd38ce6aeee2def137eb40c799af2745db874796e389d}
            : ${defconfig:=bcm2712_defconfig}
            ;;
        *)
            : ${package_version:=7.1.2}
            local package_major_version="${package_version%%.*}"
            : ${package_source:=https://www.kernel.org/pub/linux/kernel/v$package_major_version.x/linux-$package_version.tar.xz}
            : ${package_source_hash:=sha256:37198c93727be247c9fb5309bb86cd5e496c61e5322cd8c4eca9476bb0b5883f}
            ;;
    esac
fi

prepare() {
    case $package_component in
        linux)
            # Assemble a minimal kernel from allnoconfig + config fragments
            # whenever the platform ships its own machine config (base +
            # <platform> + <arch> + <init flavor>). Each <platform>.config is
            # self-contained — virt.config, pi0.config, pi4.config each carry
            # everything their machine needs (no shared "pi" layer, so the
            # Pi 0's config is never mixed into the Pi 4's). This keeps every
            # emulated target small and fast and avoids the downstream
            # defconfig's mass of drivers for hardware QEMU doesn't model.
            # base.config supplies btrfs (=y, our root fs — the Pi defconfigs
            # only build it as a module). Platforms without a machine config
            # fall back to their full defconfig.
            #
            # The fragment after $ARCH is named after $INIT (systemd.config /
            # busybox.config): systemd needs cgroups/namespaces/BPF/POSIX MQ/
            # debugfs that busybox-init never touches, so each flavor's
            # kernel only carries what its own PID 1 actually uses (see
            # those two files for the accounting). This is plain name-keyed
            # path assembly, not a conditional.
            #
            # One further fragment per entry in $CAPS (opt-in capabilities —
            # see lfs's Capabilities section), each named after the
            # capability itself (network.config, 9p.config, ...). $CAPS is
            # already sorted/de-duplicated by lfs, so the assembled file —
            # and hence the kernel it produces — is deterministic. Empty by
            # default, so a build with CAPS unset gets exactly the fragment
            # set that existed before capabilities were added.
            if [ -f "$package_files_dir/$PLATFORM.config" ]; then
                {
                    cat $package_files_dir/base.config \
                        $package_files_dir/$PLATFORM.config \
                        $package_files_dir/$ARCH.config \
                        $package_files_dir/$INIT.config
                    for cap in ${CAPS:-}; do
                        cat $package_files_dir/$cap.config
                    done
                } > $package_source_dir/combined.config
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
