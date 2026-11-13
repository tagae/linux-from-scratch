# https://sourceware.org/glibc/manual/latest/html_node/Configuring-and-compiling.html

readonly package_version=2.44
readonly package_source=https://ftp.gnu.org/gnu/glibc/glibc-$package_version.tar.xz
readonly package_source_hash=sha256:37f600f2bef3c5e8300147059568b2a2e40a7ad6ccc65ce942556d49429cc667
readonly package_description='GNU C Library.'
readonly package_license='LGPL-2.1-or-later AND GPL-2.0-or-later'

prepare() {
    case $package_component in
        glibc|headers)
            # Both patches come from the LFS book's patches, 13.1: the first moves what glibc keeps
            # in /var/db to where the FHS puts it, the second brings upstream's fixes of the release
            # branch. The second is for this release: a new glibc needs the book's own.
            apply_patch $package_files_dir/glibc-fhs-1.patch
            apply_patch $package_files_dir/glibc-${package_version}-upstream_fixes-1.patch

            : ${prefix:=/usr}
            : ${nscd:=no}

            # rootsbindir: ensure that the ldconfig and sln utilities are installed alongside the
            # rest of this glibc, rather than glibc's default /sbin.
            # ldd-rewrite-script: have ldd try the dynamic linker where this glibc installs it
            # (slibdir), rather than the lib64, lib and libx32 directories under $prefix that
            # x86-64's multilib rewrite lists, none of which holds it.
            # rtld-LDFLAGS: when rtld_dir is set, have glibc's own programs (getconf, iconv, ...)
            # run with the dynamic linker and libraries installed there, rather than with the ones
            # at the standard location.
            {
                echo "rootsbindir=$prefix/sbin"
                echo "ldd-rewrite-script=no"
                if [ -n "${rtld_dir:-}" ]; then
                    echo "rtld-LDFLAGS=-Wl,-dynamic-linker=$rtld_dir/\$(rtld-installed-name) -Wl,-rpath,$rtld_dir"
                fi
            } > configparms

            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
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
                ${timezone_tools:+--enable-timezone-tools=$timezone_tools} \
                ${prefix:+libc_cv_slibdir=$prefix/lib}
            ;;
        *)
            default_prepare
            ;;
    esac
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

            # Plus the tools for tracing, profiling and debugging programs, the compilers of
            # locales and message catalogs, and the tools for locales and character sets, which
            # have no data here (no locales, no conversion modules). And ldd, a bash script: the
            # system has no bash, and `ld.so --list` does the same.
            move_to_dev_component \
                usr/bin/mtrace usr/bin/pcprofiledump usr/bin/sotruss usr/bin/sprof usr/bin/xtrace \
                usr/lib/audit usr/lib/libc_malloc_debug.so.0 usr/lib/libthread_db.so.1 \
                usr/bin/gencat usr/bin/localedef usr/bin/ldd \
                usr/bin/locale usr/bin/iconv usr/sbin/iconvconfig usr/bin/makedb \
                usr/lib/libBrokenLocale.so.1
            ;;
        dev)
            install_component
            ;;
        *)
            default_install
            ;;
    esac
}
