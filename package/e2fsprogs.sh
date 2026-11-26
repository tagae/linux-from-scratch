: ${package_version:=1.47.4}
: ${package_source:=https://www.kernel.org/pub/linux/kernel/people/tytso/e2fsprogs/v$package_version/e2fsprogs-$package_version.tar.xz}
: ${package_source_hash:=sha256:fd5bf388cbdbe006a3d3b318d983b2948382440acc85a87f1e7d108653e8db0b}
: ${package_description:=Utilities for the ext2, ext3 and ext4 file systems.}
: ${package_license:=GPL-2.0-only AND GPL-2.0-or-later AND LGPL-2.0-only AND LGPL-2.0-or-later AND BSD-3-Clause AND HPND-export-US-modify AND Kazlib AND LicenseRef-MIT-SIPB}
: ${package_cpe:=a:e2fsprogs_project:e2fsprogs:$package_version}

prepare() {
    case $package_component in
        e2fsprogs)
            # Shared libraries. UUIDs and the probing of devices are left to util-linux's libraries,
            # and fsck, the front end that runs e2fsck, to util-linux. The systems have no initial
            # RAM file system for a helper to run in, no FUSE and no libarchive, and no use for the
            # units, cron jobs and udev rules of e2scrub, which the build leaves out.
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                --sysconfdir=/etc \
                ${nls:+--enable-nls=$nls} \
                --enable-elf-shlibs \
                --disable-libblkid \
                --disable-libuuid \
                --disable-uuidd \
                --disable-fsck \
                --disable-e2initrd-helper \
                --disable-fuse2fs \
                --without-libarchive \
                --with-udev-rules-dir=no \
                --with-crond-dir=no \
                --with-systemd-unit-dir=no
            ;;
        *)
            default_prepare
            ;;
    esac
}

# e2scrub checks the file systems of logical volumes while they are mounted, which the systems have
# none of, and is a bash script: its directory is out of the build and of the install.
build() {
    case $package_component in
        e2fsprogs)
            make E2SCRUB_DIR=
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        e2fsprogs)
            # What `make install` does, but for the Info manual of libext2fs, which takes makeinfo
            # to build.
            make E2SCRUB_DIR= DESTDIR=$package_install_dir install-progs-recursive install-libs
            # compile_et and mk_cmds write the C code of a program's error messages and commands:
            # they are for building programs.
            move_to_dev_component usr/bin/compile_et usr/bin/mk_cmds usr/share/et usr/share/ss \
                usr/share/man/man1/compile_et.1 usr/share/man/man1/mk_cmds.1
            move_to_docs_component
            ;;
        dev)
            install_component
            ;;
        *)
            default_install
            ;;
    esac
}
