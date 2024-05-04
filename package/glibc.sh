# https://sourceware.org/glibc/manual/latest/html_node/Configuring-and-compiling.html

: ${package_version:=2.39}
: ${package_source:=https://ftp.gnu.org/gnu/glibc/glibc-$package_version.tar.xz}

: ${prefix:=/usr}
: ${headers:=/usr/include}

prepare() {
    # host=target is not a mistake
    $package_source_dir/configure \
        --prefix=$prefix \
        --build=$build \
        --host=$target \
        --with-arch=$arch \
        --with-float=$float \
        --with-fpu=$fpu \
        --with-tune=$tune \
        --with-headers=$headers \
        --enable-kernel=6.1.5 \
        --disable-multilib \
        --disable-nscd
}

build() {
    case $package_component in
        glibc)
            make -j1
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        headers)
            make install-headers DESTDIR=$package_install_dir
            ;;
        glibc)
            make install DESTDIR=$package_install_dir
            if ${TOOLS:-false}; then
                make install DESTDIR=$TOOL_DIR/$target
            fi
            ;;
        *)
            default_install
            ;;
    esac
}
