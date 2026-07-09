: ${package_version:=6.6}
: ${package_source:=https://invisible-island.net/archives/ncurses/ncurses-$package_version.tar.gz}

: ${prefix:=/usr}
: ${shared:=yes}
: ${debug:=no}
: ${normal:=yes}
: ${cxx:=yes}
: ${ada:=no}
: ${pc_files:=yes}
: ${pkg_config_libdir:=/usr/lib/pkgconfig}
: ${widec:=yes}
: ${stripping:=yes}

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
                --with-shared=$shared \
                --with-debug=$debug \
                --with-normal=$normal \
                --with-cxx=$cxx \
                --with-ada=$ada \
                --enable-pc-files=$pc_files \
                --with-pkg-config-libdir=$pkg_config_libdir \
                --enable-widec=$widec \
                --enable-stripping=$stripping
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
