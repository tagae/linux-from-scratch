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
                ${cxx_shared:+--with-cxx-shared=$cxx_shared} \
                ${ada:+--with-ada=$ada} \
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
