# https://sourceware.org/glibc/manual/latest/html_node/Configuring-and-compiling.html

: ${package_version:=2.39}
: ${package_source:=https://ftp.gnu.org/gnu/glibc/glibc-$package_version.tar.xz}

: ${prefix:=/usr}
: ${headers:=/usr/include}
: ${shared:=yes}

# --with-libiconv-prefix=/opt/homebrew/opt/libiconv \
#        libc_cv_forced_unwind=yes \
#        libc_cv_c_cleanup=yes
#        --disable-lipquadmath \
#        --disable-libquadmath-support \
#        --disable-libitm


prepare() {
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
    #arm-scratch-linux-gnueabihf-gcc -H -c /dev/null
    #exit 1
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
