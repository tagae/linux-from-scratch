: ${package_version:=6.6}
: ${package_source:=https://invisible-mirror.net/archives/ncurses/ncurses-$package_version.tar.gz}
: ${package_source_hash:=sha256:355b4cbbed880b0381a04c46617b7656e362585d52e9cf84a67e2009b749ff11}
: ${package_description:=Terminal-independent text user interface library.}
: ${package_license:=X11-distribute-modifications-variant}
: ${package_cpe:=a:gnu:ncurses:$package_version}

prepare() {
    case $package_component in
        tic)
            $package_source_dir/configure \
                ${prefix:+--prefix=$prefix}
            ;;
        ncurses)
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${shared:+--with-shared=$shared} \
                ${debug:+--with-debug=$debug} \
                ${normal:+--with-normal=$normal} \
                ${cxx_binding:+--with-cxx-binding=$cxx_binding} \
                ${cxx_shared:+--with-cxx-shared=$cxx_shared} \
                ${ada:+--with-ada=$ada} \
                ${widec:+--enable-widec=$widec} \
                ${stripping:+--enable-stripping=$stripping} \
                ${fallbacks:+--with-fallbacks=$fallbacks} \
                ${db_install:+--enable-db-install=$db_install} \
                ${pc_files:+--enable-pc-files=$pc_files} \
                ${pkg_config_libdir:+--with-pkg-config-libdir=$pkg_config_libdir}
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        tic)
            make -C include
            make -C progs tic
            ;;
        ncurses)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        tic)
            env install progs/tic $prefix/bin
            ;;
        ncurses)
            make install DESTDIR=$package_install_dir
            # The tools of the terminfo database: to compile, compare, list and convert descriptions,
            # which the systems have no use for with the few that the library holds built in.
            for tool in tic infocmp toe captoinfo infotocap; do
                rm -v $package_install_dir$prefix/bin/$tool
            done
            # Plus the script that tells the flags for compiling against it.
            move_to_dev_component 'usr/bin/ncurses*-config'
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
