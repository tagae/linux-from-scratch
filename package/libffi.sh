: ${package_version:=3.8.0}
: ${package_source:=https://github.com/libffi/libffi/releases/download/v$package_version/libffi-$package_version.tar.gz}
: ${package_source_hash:=sha256:7da3e2d9a171eb0a038f592ecad3ff2bb2550f3496d87b3b29ad0cf4430c0db4}
: ${package_description:=Library to call functions whose interface is known at run time.}
: ${package_license:=MIT}
: ${package_cpe:=a:libffi_project:libffi:$package_version}

prepare() {
    case $package_component in
        libffi)
            # The library goes in lib, instead of in the multilib directory that the compiler
            # names.
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${sysroot:+--with-sysroot=$sysroot} \
                --libdir=$prefix/lib \
                --disable-multi-os-directory \
                --disable-static
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        libffi)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        libffi)
            make install DESTDIR=$package_install_dir
            # Its libtool archive makes libtool put the sysroot in the run-time path of the
            # libraries that link against it.
            rm -fv $package_install_dir$prefix/lib/libffi.la
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
