: ${package_version:=2.10.0}
: ${package_source:=https://github.com/libexpat/libexpat/releases/download/R_$(echo $package_version | tr . _)/expat-$package_version.tar.xz}
: ${package_source_hash:=sha256:c624ba2998fc65df1163a49641ff3f9ab73138b11641d92c86bee0fb01b1bc7f}
: ${package_description:=Stream-oriented XML parser library.}
: ${package_license:=MIT}
: ${package_cpe:=a:libexpat_project:libexpat:$package_version}

prepare() {
    case $package_component in
        expat)
            # Only the library: not xmlwf, the examples or the tests, nor the manual page that
            # docbook makes for xmlwf.
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${sysroot:+--with-sysroot=$sysroot} \
                --disable-static \
                --without-xmlwf \
                --without-examples \
                --without-tests \
                --without-docbook
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        expat)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        expat)
            make install DESTDIR=$package_install_dir
            # Its libtool archive makes libtool put the sysroot in the run-time path of the
            # libraries that link against it.
            rm -fv $package_install_dir$prefix/lib/libexpat.la
            move_to_dev_component usr/lib/cmake
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
