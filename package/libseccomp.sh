: ${package_version:=2.6.2}
: ${package_source:=https://github.com/seccomp/libseccomp/releases/download/v$package_version/libseccomp-$package_version.tar.gz}
: ${package_source_hash:=sha256:6b845d352c6d7887d8d134c43d86850d40f5dcee11ad1675c18197ae4d869d42}
: ${package_description:=Library for the system call filters of the Linux kernel (seccomp).}
: ${package_license:=LGPL-2.1-only}
: ${package_cpe:=a:libseccomp_project:libseccomp:$package_version}

prepare() {
    case $package_component in
        libseccomp)
            # Without the Python bindings. The tables of system calls of each architecture are
            # compiled with gperf, which runs on the build machine.
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                --disable-static
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        libseccomp)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        libseccomp)
            make install DESTDIR=$package_install_dir
            # Its libtool archive makes libtool put the sysroot in the run-time path of the
            # libraries that link against it.
            rm -fv $package_install_dir$prefix/lib/libseccomp.la
            move_to_dev_component
            move_to_docs_component
            ;;
        dev)
            install_component
            ;;
        *)
            default_install
            ;;
    esac
}
