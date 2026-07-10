: ${package_version:=6.6}
: ${package_source:=https://ftpmirror.gnu.org/ncurses/ncurses-$package_version.tar.gz}

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
                ${cxx:+--with-cxx=$cxx} \
                ${ada:+--with-ada=$ada} \
                ${pc_files:+--enable-pc-files=$pc_files} \
                ${pkg_config_libdir:+--with-pkg-config-libdir=$pkg_config_libdir} \
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
            make install DESTDIR=$package_install_dir cross_compiling=yes
            ;;
    esac
}
