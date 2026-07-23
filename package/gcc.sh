# https://gcc.gnu.org/install/build.html

: ${package_version:=16.1.0}
: ${package_source:=https://ftpmirror.gnu.org/gcc/gcc-$package_version/gcc-$package_version.tar.xz}
: ${package_source_hash:=sha256:50efb4d94c3397aff3b0d61a5abd748b4dd31d9d3f2ab7be05b171d36a510f79}

fetch() {
    default_fetch
    local dependency
    for dependency in mpfr gmp mpc; do
        sh $PROJECT_DIR/lfs fetch $dependency
        dependency_version=$(sh $PROJECT_DIR/lfs version $dependency)
        ln -sfnv \
           $SOURCE_DIR/$dependency-$dependency_version \
           $SOURCE_DIR/gcc-$package_version/$dependency
    done
}

# gmp/mpfr/mpc knobs (below, in prepare()): unset by every existing caller
# (pass1/pass1-native/pass2 in lib/tools.sh), so this gcc keeps building
# its own bundled copies symlinked in by fetch() above, exactly as before —
# a no-op there. A caller building a genuinely target-hosted gcc (host=
# $target, see package/native-toolchain.sh) instead points these at
# already-built target packages of gmp/mpfr/mpc (own cross-compiling
# ambiguity fixed at that level, see gmp.sh) — passing --with-gmp/--with-
# mpfr/--with-mpc makes gcc's own top-level configure skip configuring the
# symlinked-in bundled copies entirely (its own noconfigdirs mechanism) and
# link these prebuilt ones instead.

prepare() {
    # cross_target defaults to $target (the platform's real cross target —
    # every existing caller keeps working unchanged), but callers building
    # a build-host-native toolchain (used by build_tools()/Ch6 tools to
    # actually execute in the scratch container, as opposed to the
    # per-platform cross-compiler) explicitly pass cross_target="" to omit
    # --target/--host/--with-gxx-include-dir entirely. $target itself is
    # globally readonly and can't be reassigned even via a prefix
    # assignment, hence this separate var.
    : ${cross_target=$target}

    case $package_component in
        libstdc++)
            $package_source_dir/libstdc++-v3/configure \
                ${cross_target:+--host=$cross_target} \
                ${cross_target:+--target=$cross_target} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${multilib:+--enable-multilib=$multilib} \
                ${nls:+--enable-nls=$nls} \
                ${libstdcxx_pch:+--enable-libstdcxx-pch=$libstdcxx_pch} \
                ${cross_target:+--with-gxx-include-dir=/$cross_target/include/c++/$package_version}
            ;;
        *)
            # https://gcc.gnu.org/install/configure.html
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${cross_target:+--target=$cross_target} \
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
    make
}

install() {
    case $package_component in
        libstdc++)
            make install DESTDIR=$package_install_dir
            ;;
        *)
            make install DESTDIR=$package_install_dir
            case ${package_variant:-} in
                pass1)
                    cat $package_source_dir/gcc/limitx.h \
                        $package_source_dir/gcc/glimits.h \
                        $package_source_dir/gcc/limity.h \
                        > $($target-gcc -print-file-name=include)/limits.h
                    ;;
            esac
            ;;
    esac
}
