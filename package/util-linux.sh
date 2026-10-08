: ${package_version:=2.42.2}
: ${package_source:=https://www.kernel.org/pub/linux/utils/util-linux/v${package_version%.*}/util-linux-$package_version.tar.xz}
: ${package_source_hash:=sha256:03a05d3adf9602ef128f2da05b84b3205ce60c351e5737c0370f74000679ce8a}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${bindir:+--bindir=$bindir} \
        ${libdir:+--libdir=$libdir} \
        ${sbindir:+--sbindir=$sbindir} \
        ${all_programs:+--enable-all-programs=$all_programs} \
        ${libblkid:+--enable-libblkid=$libblkid} \
        ${libuuid:+--enable-libuuid=$libuuid} \
        ${libmount:+--enable-libmount=$libmount} \
        ${libmount_mountfd_support:+--enable-libmount-mountfd-support=$libmount_mountfd_support} \
        ${libfdisk:+--enable-libfdisk=$libfdisk} \
        ${libsmartcols:+--enable-libsmartcols=$libsmartcols} \
        ${mount:+--enable-mount=$mount} \
        ${fdisks:+--enable-fdisks=$fdisks} \
        ${losetup:+--enable-losetup=$losetup} \
        ${fallocate:+--enable-fallocate=$fallocate} \
        ${mountpoint:+--enable-mountpoint=$mountpoint} \
        ${chfn_chsh:+--enable-chfn-chsh=$chfn_chsh} \
        ${login:+--enable-login=$login} \
        ${nologin:+--enable-nologin=$nologin} \
        ${su:+--enable-su=$su} \
        ${setpriv:+--enable-setpriv=$setpriv} \
        ${runuser:+--enable-runuser=$runuser} \
        ${pylibmount:+--enable-pylibmount=$pylibmount} \
        ${static:+--enable-static=$static} \
        ${liblastlog2:+--enable-liblastlog2=$liblastlog2} \
        ${python:+--with-python=$python} \
        ${systemd:+--with-systemd=$systemd} \
        ${systemdsystemunitdir:+--with-systemdsystemunitdir=$systemdsystemunitdir} \
        ${ncurses:+--with-ncurses=$ncurses} \
        ${ncursesw:+--with-ncursesw=$ncursesw} \
        ${tinfo:+--with-tinfo=$tinfo} \
        ${wall:+--enable-wall=$wall} \
        ${makeinstall_chown:+--enable-makeinstall-chown=$makeinstall_chown} \
        ${makeinstall_setuid:+--enable-makeinstall-setuid=$makeinstall_setuid} \
        --docdir=/usr/share/doc/util-linux-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
