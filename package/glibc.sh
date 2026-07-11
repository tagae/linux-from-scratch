# https://sourceware.org/glibc/manual/latest/html_node/Configuring-and-compiling.html

: ${package_version:=2.43}
: ${package_source:=https://ftpmirror.gnu.org/glibc/glibc-$package_version.tar.xz}

prepare() {
    : ${build:=$($package_source_dir/scripts/config.guess)}
    : ${host:=$build}

    patch https://www.linuxfromscratch.org/patches/lfs/development/glibc-fhs-1.patch
    patch https://www.linuxfromscratch.org/patches/lfs/development/glibc-$package_version-upstream_fixes-1.patch

    # Ensure that the ldconfig and sln utilities are installed alongside the
    # rest of this glibc, rather than glibc's default rootsbindir=/sbin.
    echo "rootsbindir=${prefix:-/usr}/sbin" > configparms

    # --host is where glibc will run (the target machine)
    # --build is the machine doing the compilation
    $package_source_dir/configure \
        ${build:+--build=$build} \
        ${target:+--host=$target} \
        ${target:+--target=$target} \
        ${arch:+--with-arch=$arch} \
        ${float:+--with-float=$float} \
        ${fpu:+--with-fpu=$fpu} \
        ${tune:+--with-tune=$tune} \
        ${prefix:+--prefix=$prefix} \
        ${prefix:+--libdir=$prefix/lib} \
        ${headers:+--with-headers=$headers} \
        ${werror:+--enable-werror=$werror} \
        ${kernel:+--enable-kernel=$kernel} \
        ${shared:+--enable-shared=$shared} \
        ${multilib:+--enable-multilib=$multilib} \
        ${profile:+--enable-profile=$profile} \
        ${nscd:+--enable-nscd=$nscd} \
        ${prefix:+libc_cv_slibdir=$prefix/lib}
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
