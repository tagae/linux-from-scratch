: ${package_version:=6.6}
: ${package_source:=https://invisible-mirror.net/archives/ncurses/ncurses-$package_version.tar.gz}
: ${package_source_hash:=sha256:355b4cbbed880b0381a04c46617b7656e362585d52e9cf84a67e2009b749ff11}

prepare() {
    case $package_component in
        tic)
            $package_source_dir/configure \
                ${prefix:+--prefix=$prefix}
            ;;
        *)
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${shared:+--with-shared=$shared} \
                ${debug:+--with-debug=$debug} \
                ${normal:+--with-normal=$normal} \
                ${cxx_shared:+--with-cxx-shared=$cxx_shared} \
                ${ada:+--with-ada=$ada} \
                ${widec:+--enable-widec=$widec} \
                ${stripping:+--enable-stripping=$stripping}
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
            make install DESTDIR=$package_install_dir
            ;;
    esac
}
