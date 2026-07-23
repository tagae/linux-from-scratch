: ${package_version:=2.03.38}
: ${package_source:=https://sourceware.org/ftp/lvm2/LVM2.$package_version.tgz}
: ${package_source_hash:=sha256:322d44bf40de318e6e6b52c56999aaeb86b16c8267187ac2e01a44d4dc526960}

# The tarball extracts to LVM2.$version, which the lvm2 package name doesn't
# match, so this override stays (unlike multipath-tools, where the name lines
# up with the archive).
package_source_dir=$SOURCE_DIR/LVM2.$package_version

# LVM2 is a suite; this project builds only its device-mapper library
# (libdevmapper), exposed as the `device-mapper` component (install
# lvm2#device-mapper) — mirroring gcc#libstdc++ / linux#headers and
# multipath-tools#kpartx. libdevmapper is all kpartx needs; the lvm/dmsetup/
# dmeventd tools and daemon (which pull in udev/systemd/selinux/readline) are
# not built, so any other component (including the bare suite) bails.
case ${package_component:-} in
    device-mapper) ;;
    *) bail "lvm2: only the 'device-mapper' component is supported (got '${package_component:-}')" ;;
esac

# Skip udev/systemd/selinux/readline integration entirely rather than
# building those dependencies just to leave them unused.
prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --without-udev \
        --without-systemd \
        --disable-selinux \
        --disable-readline
}

build() {
    make
}

# libdm is the device-mapper library component specifically — installing
# just it (rather than `make install`) skips the lvm/dmeventd/tools binaries
# we don't need.
install() {
    make -C libdm install DESTDIR=$package_install_dir
}
