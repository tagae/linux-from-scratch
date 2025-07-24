# https://sourceware.org/glibc/manual/latest/html_node/Configuring-and-compiling.html

: ${package_version:=2.41}
: ${package_source:=https://ftp.gnu.org/gnu/glibc/glibc-$package_version.tar.xz}

: ${prefix:=/usr}
: ${headers:=/usr/include}
: ${shared:=yes}

prepare() {
    : ${build:=$($package_source_dir/scripts/config.guess)}
    : ${host:=$build}
    : ${target:=$host}

    # host=target is not a mistake
    $package_source_dir/configure \
        --prefix=$prefix \
        --build=$build \
        --host=$target \
        --target=$target \
        --with-arch=$arch \
        --with-float=$float \
        --with-fpu=$fpu \
        --with-tune=$tune \
        --with-headers=$headers \
        --enable-kernel=6.1.5 \
        --enable-shared=$shared \
        --disable-multilib \
        --disable-profile \
        --disable-nscd
}

build() {
    case $package_component in
        glibc)
            make
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
            ;;
        *)
            default_install
            ;;
    esac
}
