# https://git.musl-libc.org/cgit/musl/tree/INSTALL

: ${package_version:=1.2.6}
: ${package_source:=https://musl.libc.org/releases/musl-$package_version.tar.gz}
: ${package_source_hash:=sha256:d585fd3b613c66151fc3249e8ed44f77020cb5e6c1e635a616d3f9f82460512a}
: ${package_description:=Lightweight C library, with a dynamic linker, for Linux.}
# The project's licence (COPYRIGHT) is MIT. The files it takes from others are the regular
# expressions (TRE, BSD-2-Clause), DES crypt (FreeSec, BSD-3-Clause), blowfish crypt (public domain,
# with the fallback terms that 0BSD matches) and the math library (FreeBSD's msun, SunPro).
: ${package_license:=MIT AND BSD-2-Clause AND BSD-3-Clause AND 0BSD AND SunPro}
: ${package_cpe:=a:musl-libc:musl:$package_version}

prepare() {
    case $package_component in
        musl)
            # syslibdir: where the dynamic linker goes, in the lib that /lib links to.
            # No wrapper: the toolchain is the cross gcc, whose sysroot holds this library.
            # No static library: the system links dynamically.
            $package_source_dir/configure \
                ${host:+--target=$host} \
                ${prefix:+--prefix=$prefix} \
                ${prefix:+--syslibdir=$prefix/lib} \
                --disable-wrapper \
                --disable-static
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        musl)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        musl)
            make install DESTDIR=$package_install_dir

            # The dynamic linker is the C library itself, and answers to the `libc.so` that programs
            # list as needed. So the system holds the library as the dynamic linker, and the `libc.so`
            # that the build-time linker looks for is a link to it, in the dev component.
            local lib=$package_install_dir${prefix:-/usr}/lib ldso
            ldso=$(cd $lib && echo ld-musl-*.so.1)
            mv -fv $lib/libc.so $lib/$ldso
            ln -sv $ldso $lib/libc.so

            move_to_dev_component
            ;;
        dev)
            install_component
            ;;
        *)
            default_install
            ;;
    esac
}
