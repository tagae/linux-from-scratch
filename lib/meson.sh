# Meson Packages
# --------------
#
# Helpers for the recipes of packages that are built with meson.

# Writes the file that tells meson how to cross-compile for the platform, into the build directory.
# Its pkg-config sees the sysroot only, like that of the other packages.
meson_cross_file() {
    cat > cross.ini <<EOF
[host_machine]
system = 'linux'
cpu_family = '$target_arch'
cpu = '$target_arch'
endian = 'little'

[binaries]
c = '$host-gcc'
cpp = '$host-g++'
ar = '$host-ar'
strip = '$host-strip'
pkg-config = 'pkg-config'

[properties]
sys_root = '$sysroot'
pkg_config_libdir = ['$sysroot/usr/lib/pkgconfig', '$sysroot/usr/share/pkgconfig']
EOF
}
