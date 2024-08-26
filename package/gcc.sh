# https://gcc.gnu.org/install/build.html

: ${package_version:=14.2.0}
: ${package_source:=https://ftp.gnu.org/gnu/gcc/gcc-$package_version/gcc-$package_version.tar.xz}
: ${glibc_version:=2.41}

: ${sysroot:=/}
: ${prefix:=/usr}
: ${newlib:=no}
: ${headers:=$sysroot/usr/include}
: ${build_time_sysroot:=$sysroot}
: ${build_sysroot:=$sysroot}
: ${shared:=yes}
: ${threads:=yes}
: ${libatomic:=yes}
: ${libgomp:=yes}
: ${libquadmath:=yes}
: ${libssp:=yes}
: ${libvtv:=yes}
: ${libstdcxx:=yes}
: ${languages:=c,c++}

fetch() {
    default_fetch
    (
        cd $package_source_dir
        ./contrib/download_prerequisites
    )
}

prepare() {
    case $package_component in
        libstdc++)
            $package_source_dir/libstdc++-v3/configure \
                --host=$target \
                --build=$build \
                --prefix=$prefix \
                --disable-multilib \
                --disable-nls \
                --disable-libstdcxx-pch \
                --with-gxx-include-dir=$(dirname $TOOL_DIR)/tools/$target/include/c++/$package_version
            ;;
        *)
            # https://gcc.gnu.org/install/configure.html
            $package_source_dir/configure \
                --prefix=$prefix \
                --host=$host \
                --target=$target \
                --with-arch=$arch \
                --with-float=$float \
                --with-fpu=$fpu \
                --with-tune=$tune \
                --with-abi=$abi \
                --with-glibc-version=$glibc_version \
                --with-sysroot=$sysroot \
                --with-newlib=$newlib \
                --with-headers=$headers \
                --enable-default-pie \
                --enable-default-ssp \
                --disable-nls \
                --enable-shared=$shared \
                --disable-multilib \
                --enable-threads=$threads \
                --enable-libatomic=$libatomic \
                --enable-libgomp=$libgomp \
                --enable-libquadmath=$libquadmath \
                --enable-libssp=$libssp \
                --enable-libvtv=$libvtv \
                --enable-libstdcxx=$libstdcxx \
                --enable-languages=$languages
            ;;
    esac
}

build() {
    case $package_component in
        libstdc++)
            make
            ;;
        *)
            make all-gcc all-target-libgcc
            ;;
    esac
}

install() {
    case $package_component in
        libstdc++)
            make install DESTDIR=$package_install_dir
            ;;
        *)
            make install-gcc install-target-libgcc DESTDIR=$package_install_dir
            ;;
    esac
}
