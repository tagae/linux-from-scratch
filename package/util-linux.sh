: ${package_version:=2.42.2}
: ${package_series:=${package_version%.*}} # major.minor version
: ${package_source:=https://www.kernel.org/pub/linux/utils/util-linux/v$package_series/util-linux-$package_version.tar.xz}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${bindir:+--bindir=$bindir} \
        ${libdir:+--libdir=$libdir} \
        ${sbindir:+--sbindir=$sbindir} \
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
        --docdir=/usr/share/doc/util-linux-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
