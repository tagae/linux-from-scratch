: ${package_version:=2.42.2}
: ${package_source:=https://www.kernel.org/pub/linux/utils/util-linux/v2.42/util-linux-$package_version.tar.xz}

: ${prefix:=/usr}
: ${bindir:=/usr/bin}
: ${libdir:=/usr/lib}
: ${sbindir:=/usr/sbin}
: ${chfn_chsh:=no}
: ${login:=no}
: ${nologin:=no}
: ${su:=no}
: ${setpriv:=no}
: ${runuser:=no}
: ${pylibmount:=no}
: ${static:=no}
: ${liblastlog2:=no}
: ${python:=no}
: ${systemd:=no}
: ${systemdsystemunitdir:=no}
: ${ncurses:=no}
: ${ncursesw:=no}
: ${tinfo:=no}
: ${wall:=no}
: ${makeinstall_chown:=no}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    $package_source_dir/configure \
        --prefix=$prefix \
        --host=$host \
        --build=$build \
        --bindir=$bindir \
        --libdir=$libdir \
        --sbindir=$sbindir \
        --enable-chfn-chsh=$chfn_chsh \
        --enable-login=$login \
        --enable-nologin=$nologin \
        --enable-su=$su \
        --enable-setpriv=$setpriv \
        --enable-runuser=$runuser \
        --enable-pylibmount=$pylibmount \
        --enable-static=$static \
        --enable-liblastlog2=$liblastlog2 \
        --with-python=$python \
        --with-systemd=$systemd \
        --with-systemdsystemunitdir=$systemdsystemunitdir \
        --with-ncurses=$ncurses \
        --with-ncursesw=$ncursesw \
        --with-tinfo=$tinfo \
        --enable-wall=$wall \
        --enable-makeinstall-chown=$makeinstall_chown \
        --docdir=/usr/share/doc/util-linux-$package_version
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
