: ${package_version:=6.6}
: ${package_source:=https://invisible-island.net/archives/ncurses/ncurses-$package_version.tar.gz}

: ${prefix:=/usr}

prepare() {
    : ${build:=$($package_source_dir/build-aux/config.guess)}
    : ${host:=$build}

    case $package_component in
        tic)
            $package_source_dir/configure \
                --prefix=$prefix
            ;;
        *)
            $package_source_dir/configure \
                --prefix=$prefix \
                --host=$host \
                --build=$build \
                --with-shared \
                --without-debug \
                --without-normal \
                --without-cxx \
                --without-ada \
                --enable-pc-files \
                --with-pkg-config-libdir=/usr/lib/pkgconfig \
                --enable-widec \
                --disable-stripping
            ;;
    esac
}

build() {
    case $package_component in
        tic)
            make -C include
            make -C progs tic
            ;;
        *)
            make
            ;;
    esac
}

install() {
    case $package_component in
        tic)
            env install progs/tic $prefix/bin
            ;;
        *)
            make install DESTDIR=$package_install_dir cross_compiling=yes
            ;;
    esac
}
