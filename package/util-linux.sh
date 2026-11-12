: ${package_version:=2.42.4}
: ${package_source:=https://www.kernel.org/pub/linux/utils/util-linux/v${package_version%.*}/util-linux-$package_version.tar.xz}
: ${package_source_hash:=sha256:fbd62a100ab7bb8746ba0661255c3c48185b1e9021507c624da01fbc696330ec}
: ${package_description:=Essential Linux system utilities and libraries.}
: ${package_license:=GPL-1.0-or-later AND GPL-2.0-or-later AND LGPL-2.1-or-later AND BSD-3-Clause}

prepare() {
    case $package_component in
        util-linux)
            # libudev and libsystemd are systemd's, which is built after util-linux.
            : ${all_programs:=no} ${python:=no} ${systemd:=no} ${udev:=no}
            : ${makeinstall_chown:=no} ${makeinstall_setuid:=no}

            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${sysroot:+--with-sysroot=$sysroot} \
                ${bindir:+--bindir=$bindir} \
                ${libdir:+--libdir=$libdir} \
                ${sbindir:+--sbindir=$sbindir} \
                ${nls:+--enable-nls=$nls} \
                ${all_programs:+--enable-all-programs=$all_programs} \
                ${libblkid:+--enable-libblkid=$libblkid} \
                ${libuuid:+--enable-libuuid=$libuuid} \
                ${libmount:+--enable-libmount=$libmount} \
                ${libmount_mountfd_support:+--enable-libmount-mountfd-support=$libmount_mountfd_support} \
                ${libfdisk:+--enable-libfdisk=$libfdisk} \
                ${libsmartcols:+--enable-libsmartcols=$libsmartcols} \
                ${mount:+--enable-mount=$mount} \
                ${fsck:+--enable-fsck=$fsck} \
                ${blkid:+--enable-blkid=$blkid} \
                ${lsblk:+--enable-lsblk=$lsblk} \
                ${fdisks:+--enable-fdisks=$fdisks} \
                ${losetup:+--enable-losetup=$losetup} \
                ${swapon:+--enable-swapon=$swapon} \
                ${agetty:+--enable-agetty=$agetty} \
                ${sulogin:+--enable-sulogin=$sulogin} \
                ${dmesg:+--enable-dmesg=$dmesg} \
                ${kill:+--enable-kill=$kill} \
                ${more:+--enable-more=$more} \
                ${fallocate:+--enable-fallocate=$fallocate} \
                ${mountpoint:+--enable-mountpoint=$mountpoint} \
                ${chfn_chsh:+--enable-chfn-chsh=$chfn_chsh} \
                ${login:+--enable-login=$login} \
                ${nologin:+--enable-nologin=$nologin} \
                ${su:+--enable-su=$su} \
                ${setpriv:+--enable-setpriv=$setpriv} \
                ${runuser:+--enable-runuser=$runuser} \
                ${pylibmount:+--enable-pylibmount=$pylibmount} \
                ${liblastlog2:+--enable-liblastlog2=$liblastlog2} \
                ${python:+--with-python=$python} \
                ${systemd:+--with-systemd=$systemd} \
                ${udev:+--with-udev=$udev} \
                ${systemdsystemunitdir:+--with-systemdsystemunitdir=$systemdsystemunitdir} \
                ${ncurses:+--with-ncurses=$ncurses} \
                ${ncursesw:+--with-ncursesw=$ncursesw} \
                ${tinfo:+--with-tinfo=$tinfo} \
                ${wall:+--enable-wall=$wall} \
                ${makeinstall_chown:+--enable-makeinstall-chown=$makeinstall_chown} \
                ${makeinstall_setuid:+--enable-makeinstall-setuid=$makeinstall_setuid} \
                --disable-static \
                --disable-bash-completion
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        util-linux)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        util-linux)
            make install DESTDIR=$package_install_dir
            # agetty prints this before the login prompt.
            cp -rv $package_files_dir/etc $package_install_dir/
            move_to_dev_component
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
