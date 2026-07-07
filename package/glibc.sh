# https://sourceware.org/glibc/manual/latest/html_node/Configuring-and-compiling.html

: ${package_version:=2.43}
: ${package_source:=https://ftp.gnu.org/gnu/glibc/glibc-$package_version.tar.xz}

: ${kernel:=6.1.0}
: ${prefix:=/usr}
: ${headers:=/usr/include}
: ${shared:=yes}
: ${multilib:=no}
: ${profile:=no}
: ${nscd:=no}
: ${werror:=no}

prepare() {
    : ${build:=$($package_source_dir/scripts/config.guess)}
    : ${host:=$build}

    # --host is where glibc will run (the target machine)
    # --build is the machine doing the compilation
    $package_source_dir/configure \
        --prefix=$prefix \
        --libdir=$prefix/lib \
        --build=$build \
        --host=$target \
        --target=$target \
        ${arch:+--with-arch=$arch} \
        ${float:+--with-float=$float} \
        ${fpu:+--with-fpu=$fpu} \
        ${tune:+--with-tune=$tune} \
        --with-headers=$headers \
        --enable-werror=$werror \
        --enable-kernel=$kernel \
        --enable-shared=$shared \
        --enable-multilib=$multilib \
        --enable-profile=$profile \
        --enable-nscd=$nscd
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
            # glibc headers_install doesn't install this one
            touch $package_install_dir/$prefix/include/gnu/stubs.h
            ;;
        glibc)
            make install DESTDIR=$package_install_dir
            ;;
        *)
            default_install
            ;;
    esac
}
