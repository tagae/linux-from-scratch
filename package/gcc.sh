# https://gcc.gnu.org/install/build.html

: ${package_version:=16.1.0}
: ${package_source:=https://ftp.gnu.org/gnu/gcc/gcc-$package_version/gcc-$package_version.tar.xz}
: ${package_source_hash:=sha256:50efb4d94c3397aff3b0d61a5abd748b4dd31d9d3f2ab7be05b171d36a510f79}
: ${package_fetch_dependencies:=gmp mpfr mpc}
: ${package_description:=GNU Compiler Collection.}
: ${package_license:=GPL-3.0-or-later AND GPL-3.0-or-later WITH GCC-exception-3.1}

prepare() {
    case $package_component in
        libstdc++)
            $package_source_dir/libstdc++-v3/configure \
                ${build:+--build=$build} \
                ${target:+--host=$target} \
                ${target:+--target=$target} \
                ${prefix:+--prefix=$prefix} \
                ${multilib:+--enable-multilib=$multilib} \
                ${nls:+--enable-nls=$nls} \
                ${libstdcxx_pch:+--enable-libstdcxx-pch=$libstdcxx_pch} \
                ${target:+--with-gxx-include-dir=/$target/include/c++/$package_version}
            ;;
        runtime)
            default_prepare
            ;;
        *)
            # Fetch dependencies are built in-tree, as part of GCC itself.
            ln -sfnv $gmp_source_dir $package_source_dir/gmp
            ln -sfnv $mpfr_source_dir $package_source_dir/mpfr
            ln -sfnv $mpc_source_dir $package_source_dir/mpc

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
                ${gmp:+--with-gmp=$gmp} \
                ${mpfr:+--with-mpfr=$mpfr} \
                ${mpc:+--with-mpc=$mpc} \
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
                ${languages:+--enable-languages=$languages} \
                ${bootstrap:+--enable-bootstrap=$bootstrap}
            ;;
    esac
}

build() {
    case $package_component in
        runtime)
            default_build
            ;;
        *)
            make
            ;;
    esac
}

install() {
    case $package_component in
        runtime)
            # glibc loads libgcc_s at run time, to unwind stacks.
            mkdir -pv $package_install_dir$prefix/lib
            cp -v $($host-gcc -print-file-name=libgcc_s.so.1) $package_install_dir$prefix/lib/
            ;;
        libstdc++)
            _link_lib64
            make install DESTDIR=$package_install_dir
            ;;
        *)
            _link_lib64
            make install DESTDIR=$package_install_dir
            case ${package_variant:-} in
                pass1)
                    # The compiler just staged, not one already installed.
                    local gcc=$package_install_dir$prefix/bin/$target-gcc
                    cat $package_source_dir/gcc/limitx.h \
                        $package_source_dir/gcc/glimits.h \
                        $package_source_dir/gcc/limity.h \
                        > $($gcc -print-file-name=include)/limits.h
                    ;;
            esac
    esac
}

# Some architectures install the runtime libraries (libstdc++, libgcc_s, ...) into lib64; keep them
# next to glibc's, in lib.
_link_lib64() {
    mkdir -pv $package_install_dir$prefix/lib
    ln -sfnv lib $package_install_dir$prefix/lib64
}
