: ${package_version:=5.48}
: ${package_source:=https://astron.com/pub/file/file-$package_version.tar.gz}

: ${prefix:=/usr}
: ${bzlib:=no}
: ${xzlib:=no}
: ${zlib:=no}
: ${libseccomp:=no}

prepare() {
    : ${build:=$($package_source_dir/config.guess)}
    : ${host:=$build}

    case $package_component in
        native)
            $package_source_dir/configure \
                --prefix=$prefix \
                --disable-bzlib \
                --disable-libseccomp \
                --disable-xzlib \
                --disable-zlib
            ;;
        *)
            $package_source_dir/configure \
                --prefix=$prefix \
                --host=$host \
                --build=$build \
                --enable-bzlib=$bzlib \
                --enable-xzlib=$xzlib \
                --enable-zlip=$zlib \
                --enable-libseccomp=$libseccomp
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
