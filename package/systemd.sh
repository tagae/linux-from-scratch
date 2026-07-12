: ${package_version:=260.2}
: ${package_source:=https://github.com/systemd/systemd/archive/v$package_version/systemd-$package_version.tar.gz}

prepare() {
    # meson's cpu_family values are its own fixed vocabulary, not this
    # project's $ARCH (e.g. "arm64" here means meson's "aarch64").
    case $ARCH in
        arm64) local meson_cpu_family=aarch64 ;;
        arm)   local meson_cpu_family=arm ;;
        *)     local meson_cpu_family=$ARCH ;;
    esac

    cat > meson.ini <<EOF
[host_machine]
system = 'linux'
cpu_family = '$meson_cpu_family'
cpu = '${arch:-$meson_cpu_family}'
endian = 'little'

[binaries]
c = '$target-gcc'
cpp = '$target-g++'
ar = '$target-ar'
strip = '$target-strip'
pkg-config = 'pkg-config'

[built-in options]
prefix = '$prefix'
# systemd ships override headers (src/include/override/) supplying symbols
# missing from userspace headers — TASK_COMM_LEN, PF_KTHREAD, fchmodat2, … —
# each #include_next-ing the real header. Its meson wires them in with
# -isystem, which gcc searches after every -I but before the standard system
# dirs. So the override only wins as long as no plain -I carries a competing
# <sched.h>/<sys/stat.h>. Two would here: pkg-config rewrites libcap/libkmod's
# "-I/usr/include" into "-I$sysroot/usr/include" (which also holds glibc's
# headers), and TOOL_DIR/usr/include (for the kernel headers) holds glibc's
# too — either shadows the override, hiding the symbols above.
#
# So expose both dirs at lowest priority via -idirafter (searched after the
# standard system dirs, hence after -isystem), and tell pkg-config that
# $sysroot/usr/include is a system dir (below) so it drops the redundant bare
# -I. The override then sits ahead of every real header, as systemd intends.
# INSTALL_DIR is needed for libcap/libkmod's own headers; TOOL_DIR/$target
# (the per-target sysroot, matching this cross-compiler's own --target —
# NOT TOOL_DIR/usr, which holds the build-host-native toolchain's own
# headers instead, a different architecture entirely on e.g. pi0) for the
# kernel headers — a build-time dependency only, glibc doesn't ship them
# and INSTALL_DIR deliberately has none (see tools_bootstrap).
c_args = ['-idirafter', '$sysroot/usr/include', '-idirafter', '$TOOL_DIR/$target/usr/include']
# Some deps systemd links by full path (e.g. libfdisk.so, via libshared-fdisk)
# rather than as "-L$sysroot/usr/lib -lfdisk", so no -L reaches those links —
# and gcc's own baked-in sysroot is TOOL_DIR/$target, not INSTALL_DIR. ld
# then can't find that lib's
# own NEEDED siblings (libblkid.so.1, libuuid.so.1) to resolve their versioned
# symbols, and --no-undefined turns that into a link error. -rpath-link points
# ld's indirect-dependency search at INSTALL_DIR without affecting -l lookup.
c_link_args = ['-Wl,-rpath-link,$sysroot/usr/lib']

[properties]
sys_root = '$sysroot'
EOF

    export PKG_CONFIG_PATH=$sysroot/usr/lib/pkgconfig
    export PKG_CONFIG_SYSROOT_DIR=$sysroot
    # Makes pkg-config drop the bare "-I$sysroot/usr/include" it would emit
    # for libcap/libkmod (its harmless per-library subdir -Is stay); the
    # -idirafter in c_args covers those headers without shadowing the override.
    export PKG_CONFIG_SYSTEM_INCLUDE_PATH=$sysroot/usr/include

    # xinitrcdir below: the only thing that ever touches /etc/X11 is an
    # xinit script to set up the systemd user session on X login,
    # meaningless with no X11 packages built at all here. It's
    # unconditionally installed whenever install-sysconfdir is enabled
    # (which we want — that flag also gates several genuinely useful empty
    # dirs, like /etc/systemd/system and /etc/systemd/network), so
    # redirecting this one file into the (already-created) doc dir is the
    # only way to avoid inventing /etc/X11 for a script nothing will ever
    # source.
    meson setup $package_source_dir \
          --cross-file meson.ini \
          ${prefix:+--prefix=$prefix} \
          --buildtype=release \
          -D default-dnssec=no \
          -D firstboot=false \
          -D install-tests=false \
          -D ldconfig=false \
          -D sysusers=false \
          -D rpmmacrosdir=no \
          -D homed=disabled \
          -D userdb=false \
          -D man=disabled \
          -D mode=release \
          -D pamconfdir=no \
          -D dev-kvm-mode=0660 \
          -D nobody-group=nogroup \
          -D sysupdate=disabled \
          -D ukify=disabled \
          -D openssl=disabled \
          -D tpm2=disabled \
          -D p11kit=disabled \
          -D docdir=/usr/share/doc/systemd-$package_version \
          -D xinitrcdir=/usr/share/doc/systemd-$package_version
}

build() {
    ninja
}

install() {
    DESTDIR=$package_install_dir ninja install

    cd $package_install_dir
    cp -rv $package_files_dir/* .

    # Mask units that cannot work or are not needed in this minimal build
    mkdir -pv \
          etc/systemd/system \
          etc/systemd/system-generators

    # systemd-logind requires PAM (built without it); mask socket too
    ln -sfv /dev/null etc/systemd/system/systemd-logind.service
    ln -sfv /dev/null etc/systemd/system/systemd-logind-varlink.socket

    # systemd-gpt-auto-generator fails on btrfs /dev/root pseudo-device
    ln -sfv /dev/null etc/systemd/system-generators/systemd-gpt-auto-generator

    # Network services — not needed for minimal serial-console boot
    ln -sfv /dev/null etc/systemd/system/systemd-resolved.service
    ln -sfv /dev/null etc/systemd/system/systemd-networkd.service
    ln -sfv /dev/null etc/systemd/system/systemd-networkd-wait-online.service

    # Optional filesystem mounts and automounts — not needed for minimal boot
    ln -sfv /dev/null etc/systemd/system/tmp.mount
    ln -sfv /dev/null etc/systemd/system/dev-mqueue.mount
    ln -sfv /dev/null etc/systemd/system/sys-kernel-debug.mount
    ln -sfv /dev/null etc/systemd/system/sys-kernel-config.mount
    ln -sfv /dev/null etc/systemd/system/proc-sys-fs-binfmt_misc.mount
    ln -sfv /dev/null etc/systemd/system/proc-sys-fs-binfmt_misc.automount

    # Sockets whose backing services are masked above
    ln -sfv /dev/null etc/systemd/system/systemd-networkd.socket
    ln -sfv /dev/null etc/systemd/system/systemd-networkd-varlink.socket
    ln -sfv /dev/null etc/systemd/system/systemd-networkd-varlink-metrics.socket
    ln -sfv /dev/null etc/systemd/system/systemd-networkd-resolve-hook.socket
    ln -sfv /dev/null etc/systemd/system/systemd-resolved-varlink.socket
    ln -sfv /dev/null etc/systemd/system/systemd-resolved-monitor.socket

    # On virt, there is no BOOT partition — mask boot.mount to avoid a 90 s device timeout
    if [ "${PLATFORM:-}" = virt ]; then
        ln -sfv /dev/null etc/systemd/system/boot.mount
    fi

    # Preset file: instruct the first-boot preset to DISABLE all masked units
    # instead of trying to enable them (which would log "Failed to preset" errors)
    mkdir -pv etc/systemd/system-preset
    cat > etc/systemd/system-preset/80-lfs.preset << 'EOF'
disable systemd-logind.service
disable systemd-logind-varlink.socket
disable systemd-resolved.service
disable systemd-resolved-varlink.socket
disable systemd-resolved-monitor.socket
disable systemd-networkd.service
disable systemd-networkd.socket
disable systemd-networkd-varlink.socket
disable systemd-networkd-varlink-metrics.socket
disable systemd-networkd-resolve-hook.socket
disable systemd-networkd-wait-online.service
disable tmp.mount
disable dev-mqueue.mount
disable sys-kernel-debug.mount
disable sys-kernel-config.mount
disable proc-sys-fs-binfmt_misc.mount
disable proc-sys-fs-binfmt_misc.automount
EOF
    if [ "${PLATFORM:-}" = virt ]; then
        printf 'disable boot.mount\n' >> etc/systemd/system-preset/80-lfs.preset
    fi
}
