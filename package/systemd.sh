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

    # systemd's own src/include/override/ ships a whole family of headers
    # with #if !HAVE_XXX fallbacks for things newer than our glibc/kernel
    # headers (sched.h's TASK_COMM_LEN, sys/stat.h's fchmodat2, etc.) —
    # each does #include_next to chain to the real header, meant to sit
    # ahead of it via -isystem. But pkg-config rewrites .pc Cflags like
    # "-I/usr/include" through PKG_CONFIG_SYSROOT_DIR into
    # "-I$sysroot/usr/include" (needed so headers for packages actually
    # installed under INSTALL_DIR, like libcap, can be found) — and gcc
    # always searches every -I path before any -isystem path regardless of
    # command-line order, so that sysroot path wins over the override for
    # plain names like <sched.h>. Adding the override directory itself as
    # an ordinary -I doesn't help either: meson appends cross-file c_args
    # after dependency-injected -I flags, so it still loses that ordering
    # race. -include sidesteps the whole problem: it's textually
    # equivalent to inserting this at the very top of every translation
    # unit, before any #include resolution happens at all.
    # No #include here at all, not even <sys/types.h> for mode_t: -include
    # forces this in before config.h even runs, which is what fixes the
    # ordering problem above — but it means any header pulled in this
    # early gets its content locked in by include guards before config.h's
    # own feature-test macros (_FILE_OFFSET_BITS=64, etc.) take effect,
    # breaking later, unrelated types (struct dirent64, O_LARGEFILE, …).
    # mode_t is an unsigned int on every glibc/Linux target regardless.
    cat > $package_build_dir/compat.h <<'COMPATEOF'
#ifndef TASK_COMM_LEN
#define TASK_COMM_LEN 16
#endif
#ifndef PF_KTHREAD
#define PF_KTHREAD 0x00200000
#endif
#ifndef HAVE_CLONE
#define HAVE_CLONE 1
#endif
extern int fchmodat2(int dirfd, const char *pathname, unsigned int mode, int flags);
COMPATEOF

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
# Kernel headers are a build-time dependency only — glibc doesn't ship
# them, and INSTALL_DIR deliberately has none, so they only exist under
# TOOL_DIR (see tools_bootstrap). See compat.h above for TASK_COMM_LEN/
# fchmodat2.
c_args = ['-I$TOOL_DIR/usr/include', '-include', '$package_build_dir/compat.h']

[properties]
sys_root = '$sysroot'
EOF

    export PKG_CONFIG_PATH=$sysroot/usr/lib/pkgconfig
    export PKG_CONFIG_SYSROOT_DIR=$sysroot

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
          -D docdir=/usr/share/doc/systemd-$package_version
}

build() {
    ninja
}

install() {
    DESTDIR=$package_install_dir ninja install
}
