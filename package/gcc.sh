# https://gcc.gnu.org/install/build.html

: ${package_version:=16.1.0}
: ${package_source:=https://ftpmirror.gnu.org/gcc/gcc-$package_version/gcc-$package_version.tar.xz}

fetch() {
    default_fetch
    mpfr_version=$(version mpfr)
    ln -s $SOURCE_DIR/mpfr-$mpfr_version source/gcc-$package_version/mpfr
}

prepare() {
    case $package_component in
        libstdc++)
            $package_source_dir/libstdc++-v3/configure \
                ${target:+--host=$target} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${multilib:+--enable-multilib=$multilib} \
                ${nls:+--enable-nls=$nls} \
                --disable-libstdcxx-pch \
                --with-gxx-include-dir=/$target/include/c++/$package_version
            ;;
        *)
            # https://gcc.gnu.org/install/configure.html
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${target:+--target=$target} \
                ${arch:+--with-arch=$arch} \
                ${float:+--with-float=$float} \
                ${fpu:+--with-fpu=$fpu} \
                ${tune:+--with-tune=$tune} \
                ${abi:+--with-abi=$abi} \
                ${prefix:+--prefix=$prefix} \
                ${glibc_version:+--with-glibc-version=$glibc_version} \
                ${sysroot:+--with-sysroot=$sysroot} \
                ${build_sysroot:+--with-build-sysroot=$build_sysroot} \
                ${newlib:+--with-newlib=$newlib} \
                ${headers:+--with-headers=$headers} \
                ${default_pie:+--enable-$default_pie} \
                ${default_ssp:+--enable-$default_ssp} \
                ${fixincludes:+--enable-fixincludes=$fixincludes} \
                ${nls:+--enable-nls=$nls} \
                ${shared:+--enable-shared=$shared} \
                ${multilib:+--enable-multilib=$multilib} \
                ${threads:+--enable-threads=$threads} \
                ${libatomic:+--enable-libatomic=$libatomic} \
                ${libgomp:+--enable-libgomp=$libgomp} \
                ${libquadmath:+--enable-libquadmath=$libquadmath} \
                ${libssp:+--enable-libssp=$libssp} \
                ${libvtv:+--enable-libvtv=$libvtv} \
                ${libstdcxx:+--enable-libstdcxx=$libstdcxx} \
                ${libsanitizer:+--enable-libsanitizer=$libsanitizer} \
                ${languages:+--enable-languages=$languages}
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
