# https://gcc.gnu.org/install/build.html

: ${package_version:=16.1.0}
: ${package_source:=https://ftp.gnu.org/gnu/gcc/gcc-$package_version/gcc-$package_version.tar.xz}
: ${glibc_version:=2.43}

: ${sysroot:=/}
: ${prefix:=/usr}
: ${newlib:=no}
: ${headers:=$sysroot/usr/include}
: ${build_sysroot:=$sysroot}
: ${shared:=yes}
: ${threads:=yes}
: ${libatomic:=yes}
: ${libgomp:=yes}
: ${libquadmath:=yes}
: ${libssp:=yes}
: ${libvtv:=yes}
: ${libstdcxx:=yes}
: ${libsanitizer:=yes}
: ${languages:=c,c++}

fetch() {
    default_fetch
    (
        cd $package_source_dir
        ./contrib/download_prerequisites
    )
}

prepare() {
    : ${build:=$($package_source_dir/config.guess)}
    : ${host:=$build}
    [ -n "${target:-}" ] || target=$host

    case $package_component in
        libstdc++)
            $package_source_dir/libstdc++-v3/configure \
                --host=$target \
                --build=$build \
                --prefix=$prefix \
                --disable-multilib \
                --disable-nls \
                --disable-libstdcxx-pch \
                --with-gxx-include-dir=/usr/include/c++/$package_version
            ;;
        *)
            # https://gcc.gnu.org/install/configure.html
            $package_source_dir/configure \
                --prefix=$prefix \
                --host=$host \
                --target=$target \
                ${arch:+--with-arch=$arch} \
                ${float:+--with-float=$float} \
                ${fpu:+--with-fpu=$fpu} \
                ${tune:+--with-tune=$tune} \
                ${abi:+--with-abi=$abi} \
                --with-glibc-version=$glibc_version \
                --with-sysroot=$sysroot \
                ${build_sysroot:+--with-build-sysroot=$build_sysroot} \
                --with-newlib=$newlib \
                $([ "$host" != "$target" ] && echo "--with-headers=$headers") \
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
                --enable-libsanitizer=$libsanitizer \
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
            if [ "${libatomic:-yes}" != no ]; then
                make all-target-libatomic
            fi
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
            if [ "${libatomic:-yes}" != no ]; then
                make install-target-libatomic DESTDIR=$package_install_dir
            fi
            ;;
    esac
}
