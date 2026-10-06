# https://sourceware.org/glibc/manual/latest/html_node/Configuring-and-compiling.html

readonly package_version=2.44
readonly package_source=https://ftp.gnu.org/gnu/glibc/glibc-$package_version.tar.xz
readonly package_source_hash=sha256:37f600f2bef3c5e8300147059568b2a2e40a7ad6ccc65ce942556d49429cc667

prepare() {
    patch_source https://www.linuxfromscratch.org/patches/lfs/$lfs_version/glibc-fhs-1.patch \
                 sha256:643552db030e2f2d7ffde4f558e0f5f83d3fabf34a2e0e56ebdb49750ac27b0d
    patch_source  https://www.linuxfromscratch.org/patches/lfs/$lfs_version/glibc-${package_version}-upstream_fixes-1.patch \
                 sha256:500567ff0a22e295bfe3b55e9b397796f71a19f01e1ff7fb29c9189482ee1809

    # Ensure that the ldconfig and sln utilities are installed alongside the
    # rest of this glibc, rather than glibc's default rootsbindir=/sbin.
    echo "rootsbindir=${prefix:-/usr}/sbin" > configparms

    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${target:+--target=$target} \
        ${arch:+--with-arch=$arch} \
        ${float:+--with-float=$float} \
        ${fpu:+--with-fpu=$fpu} \
        ${tune:+--with-tune=$tune} \
        ${prefix:+--prefix=$prefix} \
        ${prefix:+--libdir=$prefix/lib} \
        ${headers:+--with-headers=$headers} \
        ${werror:+--enable-werror=$werror} \
        ${enable_kernel:+--enable-kernel=$enable_kernel} \
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
            # LINGUAS= skips installing translated message catalogs
            make install DESTDIR=$package_install_dir LINGUAS=

            # Avoid i18n: drop locale/charmap source data and the loadable gconv charset modules.
            # Basic ASCII/UTF-8 conversions are handled by libc's built-in logic.
            rm -rf $package_install_dir${prefix:-/usr}/share/i18n
            rm -rf $package_install_dir${prefix:-/usr}/lib/gconv
            ;;
        *)
            default_install
            ;;
    esac
}
