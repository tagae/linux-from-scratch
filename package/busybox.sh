: ${package_version:=1.37.0}
: ${package_source:=https://busybox.net/downloads/busybox-$package_version.tar.bz2}
: ${package_source_hash:=sha256:3311dff32e746499f4df0d5df04d7eb396382d7e108bb9250e7b519b837043a4}

prepare() {
    make -C $package_source_dir ARCH=$ARCH CROSS_COMPILE=$target- defconfig
    # Answer all new Kconfig prompts with defaults first
    yes "" | make -C $package_source_dir ARCH=$ARCH CROSS_COMPILE=$target- oldconfig
    # Then apply our overrides so they are not overridden by oldconfig defaults
    #
    # DEPMOD: every bootable umbrella ships the real kmod (require kmod in
    # bootable-systemd.sh/bootable-busybox.sh), whose depmod symlink lands
    # at usr/bin — but busybox's own stub applet lands at usr/sbin, which
    # root's default login PATH searches FIRST, so the stub shadows the
    # real tool on every booted system. The stub has no `-b`, which the
    # kernel's own `make modules_install` (scripts/depmod.sh) requires —
    # empirically broke the e2e builder guest's in-guest kernel build.
    # Nothing ever needs busybox's stub: modules.dep is generated at
    # image-build time by the real kmod, never at runtime on a target.
    sed -i \
        -e 's|^# CONFIG_STATIC is not set$|CONFIG_STATIC=y|' \
        -e 's|^CONFIG_STATIC=.*$|CONFIG_STATIC=y|' \
        -e 's|^CONFIG_TC=y|# CONFIG_TC is not set|' \
        -e 's|^CONFIG_SHA1_HWACCEL=y|# CONFIG_SHA1_HWACCEL is not set|' \
        -e 's|^CONFIG_SHA256_HWACCEL=y|# CONFIG_SHA256_HWACCEL is not set|' \
        -e 's|^CONFIG_DEPMOD=y|# CONFIG_DEPMOD is not set|' \
        $package_source_dir/.config
    make -C $package_source_dir ARCH=$ARCH CROSS_COMPILE=$target- silentoldconfig </dev/null
}

build() {
    yes "" | make -C $package_source_dir ARCH=$ARCH CROSS_COMPILE=$target-
}

install() {
    # busybox's own install.sh writes straight to bin/, sbin/, usr/bin/,
    # usr/sbin/ (the classic split-usr FHS layout, not this project's
    # merged-usr one) — it never creates these as symlinks itself. Under
    # the old flow every package DESTDIR-installed straight into the one
    # shared, already-merged tree, so this "just worked": system-files had
    # already turned bin/sbin into symlinks to usr/bin/usr/sbin *in that
    # same tree* before busybox ever ran, so busybox's own bin/ash write
    # landed at usr/bin/ash for free, with no duplication. Now busybox
    # DESTDIR-installs into its own fresh, isolated stage dir (see
    # target_build_env/_source) that system-files' symlinks never touch —
    # left alone, busybox would instead create REAL bin/sbin directories
    # here, which later clobber the merged tree's symlinks on merge
    # (tar overwrites a symlink with a real directory when the archive
    # entry is one). Recreate system-files' own precondition locally, in
    # this stage, before busybox's install runs, to reproduce the exact
    # same consolidated-into-usr result its build never learned to do on
    # its own.
    mkdir -p $package_install_dir/usr/bin $package_install_dir/usr/sbin
    ln -sfn usr/bin  $package_install_dir/bin
    ln -sfn usr/sbin $package_install_dir/sbin

    make -C $package_source_dir \
        ARCH=$ARCH \
        CROSS_COMPILE=$target- \
        CONFIG_PREFIX=$package_install_dir \
        install
}
