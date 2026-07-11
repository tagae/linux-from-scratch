: ${package_version:=5.48}
: ${package_source:=https://astron.com/pub/file/file-$package_version.tar.gz}

prepare() {
    case $package_component in
        native)
            $package_source_dir/configure \
                ${prefix:+--prefix=$prefix} \
                --disable-bzlib \
                --disable-libseccomp \
                --disable-xzlib \
                --disable-zlib
            ;;
        *)
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${bzlib:+--enable-bzlib=$bzlib} \
                ${xzlib:+--enable-xzlib=$xzlib} \
                ${zlib:+--enable-zlip=$zlib} \
                ${libseccomp:+--enable-libseccomp=$libseccomp}
            ;;
    esac
}

build() {
    case $package_component in
        native)
            make
            ;;
        *)
            # libtool wrapper resolves .libs/file relative to its own directory
            make FILE_COMPILE=$(dirname $package_build_dir)/native/src/file
            ;;
    esac
}

install() {
    case $package_component in
        native)
            ;;
        *)
            make install DESTDIR=$package_install_dir
            rm -f $package_install_dir/$prefix/lib/libmagic.la
            ;;
    esac
}
