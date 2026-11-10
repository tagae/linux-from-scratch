: ${package_version:=1.3.2}
: ${package_source:=https://github.com/madler/zlib/releases/download/v$package_version/zlib-$package_version.tar.xz}
: ${package_source_hash:=sha256:d7a0654783a4da529d1bb793b7ad9c3318020af77667bcae35f95d0e42a792f3}
: ${package_description:=Deflate compression library.}
: ${package_license:=Zlib}
: ${package_cpe:=a:zlib:zlib:$package_version}

prepare() {
    case $package_component in
        zlib)
            # The toolchain for the platform is named by CHOST.
            env ${host:+CHOST=$host} $package_source_dir/configure ${prefix:+--prefix=$prefix}
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        zlib)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        zlib)
            make install DESTDIR=$package_install_dir
            rm -fv $package_install_dir/$prefix/lib/libz.a
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
