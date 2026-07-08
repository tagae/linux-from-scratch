# https://gcc.gnu.org/install/build.html

: ${package_version:=16.1.0}
: ${package_source:=https://ftp.gnu.org/gnu/gcc/gcc-$package_version/gcc-$package_version.tar.xz}
: ${glibc_version:=2.43}

: ${sysroot:=/}
: ${prefix:=/usr}
: ${newlib:=no}
: ${headers:=}
: ${build_sysroot:=$sysroot}
: ${nls:=yes}
: ${shared:=yes}
: ${libsanitizer:=yes}
: ${multilib:=no}
: ${threads:=yes}
: ${libatomic:=yes}
: ${libgomp:=yes}
: ${libquadmath:=yes}
: ${libssp:=yes}
: ${libvtv:=yes}
: ${libstdcxx:=yes}
: ${fixincludes:=yes}
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
    : ${target:=$host}

    case $package_component in
        libstdc++)
            $package_source_dir/libstdc++-v3/configure \
                --host=$target \
                --build=$build \
                --prefix=$prefix \
                --enable-multilib=$multilib \
                --enable-nls=$nls \
                --disable-libstdcxx-pch \
                --with-gxx-include-dir=/$target/include/c++/$package_version
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
                ${headers:+--with-headers=$headers} \
                --enable-default-pie \
                --enable-default-ssp \
                --enable-fixincludes=$fixincludes \
                --enable-nls=$nls \
                --enable-shared=$shared \
                --enable-multilib=$multilib \
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
            case ${package_variant:-} in
                pass1)
                    make all-gcc all-target-libgcc
                    if [ "${libatomic:-yes}" != no ]; then
                        make all-target-libatomic
                    fi
                    ;;
                *)
                    make
                    ;;
            esac
            ;;
    esac
}

install() {
    case $package_component in
        libstdc++)
            make install DESTDIR=$package_install_dir
            ;;
        *)
            case ${package_variant:-} in
                pass1)
                    make install-gcc install-target-libgcc DESTDIR=$package_install_dir
                    if [ "${libatomic:-yes}" != no ]; then
                        make install-target-libatomic DESTDIR=$package_install_dir
                    fi
                    cat $package_source_dir/gcc/limitx.h \
                        $package_source_dir/gcc/glimits.h \
                        $package_source_dir/gcc/limity.h \
                        > $($target-gcc -print-file-name=include)/limits.h
                    ;;
                *)
                    make install DESTDIR=$package_install_dir
                    ;;
            esac
            ;;
    esac
}
