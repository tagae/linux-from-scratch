: ${package_version:=260.2}
: ${package_source:=https://github.com/systemd/systemd/archive/v$package_version/systemd-$package_version.tar.gz}
: ${package_source_hash:=sha256:71a9ed11cf773478b0d7a16cd96e39ca3c3939ab37ed9a8ee814c31ea9b4f2b5}

prepare() {
    # meson's cpu_family values are its own fixed vocabulary, not this
    # project's $ARCH (e.g. "arm64" here means meson's "aarch64").
    case $ARCH in
        arm64) local meson_cpu_family=aarch64 ;;
        arm)   local meson_cpu_family=arm ;;
        *)     local meson_cpu_family=$ARCH ;;
    esac

    # Guest phase (LFS_PHASE=guest): host==build==target for real here (a
    # genuine native build), unlike the container's own
    # cross build where host==target but build is the container's own
    # architecture — see target_build_env/guest_build_env in lib/package.sh
    # and build_system()'s own guest-phase call to the former. But this
    # meson.ini's [binaries]/[host_machine] describe a CROSS build either
    # way (that's the whole point of a cross-file), which makes meson
    # default to assuming compiled binaries can't just be executed here
    # (needs_exe_wrapper, defaulting true with no exe_wrapper= configured) —
    # wrong on the guest, where they genuinely can run directly, and fatal:
    # systemd's own meson.build compiles and RUNS several codegen helpers
    # during configuration. Keeping the cross-file itself byte-identical
    # (rather than skipping it) keeps the container's own cross path
    # completely unaffected by this guest-only property.
    local needs_exe_wrapper=
    if _os_is_build_host; then
        needs_exe_wrapper='needs_exe_wrapper = false'
    fi

    # Kernel UAPI headers for c_args below: normally the container's own
    # per-target sysroot ($TOOL_DIR/$target/usr/include) — doesn't exist on
    # the guest (no TOOL_DIR there at all, see lfs). The guest's own live
    # /usr/include has them instead (unarchived straight onto "/" — see
    # native-toolchain.sh) — same fixup, and same "confirmed empirically,
    # not harmless when missing" story, as target_sysroot_cc's own copy of
    # this in lib/package.sh; see there for the full account.
    local kernel_headers=$TOOL_DIR/$target/usr/include
    if [ ! -d "$kernel_headers" ]; then
        kernel_headers=/usr/include
    fi

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
c_args = ['-idirafter', '$sysroot/usr/include', '-idirafter', '$kernel_headers']
# Some deps systemd links by full path (e.g. libfdisk.so, via libshared-fdisk)
# rather than as "-L$sysroot/usr/lib -lfdisk", so no -L reaches those links —
# and gcc's own baked-in sysroot is TOOL_DIR/$target, not INSTALL_DIR. ld
# then can't find that lib's
# own NEEDED siblings (libblkid.so.1, libuuid.so.1) to resolve their versioned
# symbols, and --no-undefined turns that into a link error. -rpath-link points
# ld's indirect-dependency search at INSTALL_DIR without affecting -l lookup.
#
# --sysroot=$sysroot: pkg-config-discovered deps (libcap/libmount/libblkid/
# libkmod, via PKG_CONFIG_LIBDIR below) DO reach the link line as explicit
# "-L$sysroot/usr/lib", ahead of gcc's own default library search path — so
# the implicit "-lc" gcc adds resolves against INSTALL_DIR's glibc first.
# INSTALL_DIR's libc.so is an ld script with bare absolute paths
# (GROUP ( /usr/lib/libc.so.6 ... )); without --sysroot active those resolve
# against the container's real root (the scratch container's bind-mounted
# TOOL_DIR/usr/lib — the toolchain's native, build-host-arch runtime)
# instead of INSTALL_DIR, breaking with "file format not recognized" on any
# target whose arch differs from the build host's (e.g. pi0/arm on an
# aarch64 host).
c_link_args = ['--sysroot=$sysroot', '-Wl,-rpath-link,$sysroot/usr/lib']

[properties]
sys_root = '$sysroot'
$needs_exe_wrapper
EOF

    # PKG_CONFIG_LIBDIR (which *replaces* pkgconf's compiled-in default
    # search path), not PKG_CONFIG_PATH (which only *adds* to it): this is a
    # cross build, so pkg-config must see the target sysroot's .pc files and
    # ONLY those. The scratch container bind-mounts TOOL_DIR/usr/lib onto
    # /usr/lib, so pkgconf's default /usr/lib/pkgconfig otherwise exposes the
    # build tools' own .pc files (liblzma, zlib, libssl, ... from the xz/
    # zlib/openssl built in the tools phase). meson would then auto-detect
    # and enable e.g. xz — and systemd's compress.c would #include <lzma.h>,
    # which does not exist in the target sysroot ($sysroot/usr/include),
    # breaking the build. Scoping to $sysroot keeps the genuinely-needed
    # target libs (libcap/libmount/libblkid/libkmod/...) while dropping the
    # host-tool leak, so optional features with no target library simply
    # stay disabled.
    export PKG_CONFIG_LIBDIR=$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig
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

    # Network services — not needed for minimal serial-console boot.
    # systemd-networkd's and systemd-resolved's masks (and, below, their
    # sockets') are skipped when CAPS contains network — same
    # conditional-at-the-source reasoning as tmp.mount below: merge is
    # additive-only, so network-config.sh could never delete a mask
    # merged here; it only ships enable symlinks and configuration
    # (resolved handles DNS from DHCP plus mDNS/.local — see there).
    # wait-online stays masked even with networking: it would gate boot
    # on network availability.
    if ! has_cap network; then
        ln -sfv /dev/null etc/systemd/system/systemd-resolved.service
        ln -sfv /dev/null etc/systemd/system/systemd-networkd.service
    fi
    ln -sfv /dev/null etc/systemd/system/systemd-networkd-wait-online.service

    # Optional filesystem mounts and automounts — not needed for minimal boot.
    # tmp.mount is skipped when CAPS=amnesia (see package/amnesia-config.sh):
    # a masked unit here always wins over the fstab-generator's own
    # synthesized tmp.mount (etc/systemd/system/ outranks the generator's
    # /run/systemd/generator/ in systemd's unit load order — see
    # systemd.unit(5)'s UNIT FILE LOAD PATH), so amnesia's own /etc/fstab
    # tmpfs entry for /tmp would otherwise be silently shadowed.
    #
    # A mask can NOT be reversed by a later package's own install() —
    # confirmed empirically while building the amnesia capability: since
    # the stage->archive->merge inversion, every package's
    # package_install_dir is its own fresh, empty per-package stage dir;
    # `rm -fv` there removes nothing (the path was never there to begin
    # with), and merge only extracts paths a package's OWN tarball actually
    # contains — it can add or overwrite, never delete something an
    # earlier package already merged. Gating each mask right here, at the
    # one place that actually controls the merged tree's content, is the
    # only way to make it conditional (the networkd masks above/below are
    # gated the same way for the same reason).
    if ! has_cap amnesia; then
        ln -sfv /dev/null etc/systemd/system/tmp.mount
    fi
    ln -sfv /dev/null etc/systemd/system/dev-mqueue.mount
    ln -sfv /dev/null etc/systemd/system/sys-kernel-debug.mount
    ln -sfv /dev/null etc/systemd/system/sys-kernel-config.mount
    ln -sfv /dev/null etc/systemd/system/proc-sys-fs-binfmt_misc.mount
    ln -sfv /dev/null etc/systemd/system/proc-sys-fs-binfmt_misc.automount

    # Sockets whose backing services are masked above. networkd's netlink
    # socket and resolved's varlink/monitor sockets follow their services'
    # CAPS gate (networkd's is named in its unit's Sockets= and needed for
    # a DHCP lease; resolved's varlink socket serves resolvectl); the
    # networkd varlink/metrics/resolve-hook sockets stay masked even with
    # networking — not needed to bring an interface up.
    if ! has_cap network; then
        ln -sfv /dev/null etc/systemd/system/systemd-networkd.socket
        ln -sfv /dev/null etc/systemd/system/systemd-resolved-varlink.socket
        ln -sfv /dev/null etc/systemd/system/systemd-resolved-monitor.socket
    fi
    ln -sfv /dev/null etc/systemd/system/systemd-networkd-varlink.socket
    ln -sfv /dev/null etc/systemd/system/systemd-networkd-varlink-metrics.socket
    ln -sfv /dev/null etc/systemd/system/systemd-networkd-resolve-hook.socket

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
