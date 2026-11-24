: ${package_version:=2.7.0}
: ${package_source:=https://duktape.org/duktape-$package_version.tar.xz}
: ${package_source_hash:=sha256:90f8d2fa8b5567c6899830ddef2c03f3c27960b11aca222fa17aa7ac613c2890}
: ${package_description:=Embeddable JavaScript engine.}
: ${package_license:=MIT}
: ${package_cpe:=a:duktape:duktape:$package_version}

# The distribution's own makefile for a shared library, which also makes the pkg-config file from
# its template: the build directory has the template, and the makefile reads the sources of the
# combined distribution from the source directory.
_make_duktape() {
    cp $package_source_dir/duktape.pc.in .
    make -f $package_source_dir/Makefile.sharedlibrary \
        CC="${CC:-${host:+$host-}gcc}" \
        DUKTAPE_SRCDIR=$package_source_dir/src \
        INSTALL_PREFIX=$prefix \
        LIBDIR=/lib \
        DESTDIR=$package_install_dir \
        "$@"
}

build() {
    case $package_component in
        duktape)
            _make_duktape all
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        duktape)
            _make_duktape install
            cd $package_install_dir

            # The library with debugging information is for debugging Duktape.
            rm -v usr/lib/libduktaped.so*

            move_to_dev_component
            ;;
        dev)
            install_component
            ;;
        *)
            default_install
            ;;
    esac
}
