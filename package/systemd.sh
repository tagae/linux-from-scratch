: ${package_version:=257.6}
: ${package_source:=https://github.com/systemd/systemd/archive/v$package_version/systemd-$package_version.tar.gz}

: ${prefix:=/usr}
: ${sysroot:=/}

prepare() {
    cat > meson.ini <<EOF
[host_machine]
system = 'linux'
cpu_family = '$ARCH'
cpu = '$tune'
endian = 'little'

[binaries]
c = '$target-gcc'
cpp = '$target-g++'
ar = '$target-ar'
strip = '$target-strip'
pkg-config = 'pkg-config'

[built-in options]
prefix = '$prefix'
sys_root = '$sysroot'
EOF

    export PKG_CONFIG_PATH=$package_install_dir/usr/lib/pkgconfig
    export PKG_CONFIG_SYSROOT_DIR=$package_install_dir

    meson setup $package_source_dir \
          --cross-file meson.ini \
          --prefix=$prefix \
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
          -D docdir=/usr/share/doc/systemd-$package_version
}
