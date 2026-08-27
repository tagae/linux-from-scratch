: ${package_version:=1.0.27}
: ${package_source:=https://github.com/libusb/libusb/releases/download/v$package_version/libusb-$package_version.tar.bz2}
: ${package_source_hash:=sha256:ffaa41d741a8a3bee244ac8e54a72ea05bf2879663c098c82fc5757853441575}

# scdaemon's internal CCID driver talks to a YubiKey directly over USB
# through this — no pcscd/libccid stack needed.
# host/prefix/install-dir come from target_build_env (applied by install()
# for a standalone `./lfs install`); build= forces autoconf to treat a
# same-arch target (virt/pi4) as a cross build; target_sysroot_cc compiles
# against the target tree's own libc (see lib/package.sh).
: ${build:=$(gcc -dumpmachine)}
target_sysroot_cc

prepare() {
    # --disable-udev: keeps libusb dependency-free — udev is only used for
    # hotplug notifications, not basic enumeration/transfer, and linking it
    # would drag a udev library into the target this package otherwise needs
    # none of.
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-udev
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
