: ${package_version:=2.03.38}
: ${package_source:=https://sourceware.org/ftp/lvm2/LVM2.$package_version.tgz}
: ${package_source_sha256:=322d44bf40de318e6e6b52c56999aaeb86b16c8267187ac2e01a44d4dc526960}

package_source_dir=$SOURCE_DIR/LVM2.$package_version

# We only need libdevmapper (for kpartx) — not the lvm/dmeventd tools or
# daemon, so skip udev/systemd/selinux/readline integration entirely
# rather than building those dependencies just to leave them unused.
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
