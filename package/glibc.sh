# https://sourceware.org/glibc/manual/latest/html_node/Configuring-and-compiling.html

: ${package_version:=2.43}
: ${package_source:=https://ftpmirror.gnu.org/glibc/glibc-$package_version.tar.xz}
: ${package_source_hash:=sha256:d9c86c6b5dbddb43a3e08270c5844fc5177d19442cf5b8df4be7c07cd5fa3831}

prepare() {
    : ${build:=$($package_source_dir/scripts/config.guess)}

    # cross_target defaults to $target (the platform's real cross target —
    # every existing caller keeps working unchanged), but callers building
    # a build-host-native glibc (the runtime library TOOL_DIR's own tools
    # need to execute in the scratch container, as opposed to the
    # per-platform target sysroot glibc) explicitly pass cross_target="" to
    # omit --host/--target entirely (native build, host=build via the
    # $build computed above). $target itself is globally readonly and
    # can't be reassigned even via a prefix assignment, hence this
    # separate var.
    : ${cross_target=$target}

    patch_source https://www.linuxfromscratch.org/patches/lfs/development/glibc-fhs-1.patch
    patch_source https://www.linuxfromscratch.org/patches/lfs/development/glibc-$package_version-upstream_fixes-1.patch

    # Ensure that the ldconfig and sln utilities are installed alongside the
    # rest of this glibc, rather than glibc's default rootsbindir=/sbin.
    echo "rootsbindir=${prefix:-/usr}/sbin" > configparms

    # --host is where glibc will run (the target machine)
    # --build is the machine doing the compilation
    $package_source_dir/configure \
        ${build:+--build=$build} \
        ${cross_target:+--host=$cross_target} \
        ${cross_target:+--target=$cross_target} \
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
            # (po/Makefile's own documented override), which also means
            # msgfmt is never invoked, sidestepping its iconv/gconv
            # dependency entirely. Safe to override on the command line:
            # "LINGUAS" isn't a name any other subdir's Makefile reuses.
            make install DESTDIR=$package_install_dir LINGUAS=

            # No i18n needed for a minimal Busybox/systemd target: drop
            # locale/charmap source data and the loadable gconv charset
            # modules after the fact, rather than fighting to suppress
            # their install — glibc's own Makefiles reuse plain variable
            # names like "charmaps" for unrelated purposes in other
            # subdirs (iconvdata's own charmap-relative build path, for
            # one), so a command-line override aimed at localedata ends up
            # clobbering those too. Basic ASCII/UTF-8 conversions are
            # handled by libc's built-in fast path with no module files at
            # all; only legacy/exotic charsets need what's being removed.
            rm -rf $package_install_dir${prefix:-/usr}/share/i18n
            rm -rf $package_install_dir${prefix:-/usr}/lib/gconv
            ;;
        *)
            default_install
            ;;
    esac
}
