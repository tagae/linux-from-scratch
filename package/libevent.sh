: ${package_version:=2.1.13}
: ${package_source:=https://github.com/libevent/libevent/releases/download/release-$package_version-stable/libevent-$package_version-stable.tar.gz}
: ${package_source_hash:=sha256:f7e9383b8c0baa81b687e5b5eecc01beefaf1b19b64151d95ed61647fe7a315c}
: ${package_description:=Event notification library.}
: ${package_license:=BSD-3-Clause AND ISC}
: ${package_cpe:=a:libevent_project:libevent:$package_version}

package_source_dir=$source_dir/libevent-$package_version-stable

prepare() {
    case $package_component in
        libevent)
            # Without the bufferevents over OpenSSL, which configure otherwise builds where the
            # sysroot holds OpenSSL.
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${sysroot:+--with-sysroot=$sysroot} \
                --disable-openssl \
                --disable-samples \
                --disable-libevent-regress \
                --disable-static
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        libevent)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        libevent)
            make install DESTDIR=$package_install_dir
            # Its libtool archives make libtool put the sysroot in the run-time path of the
            # libraries that link against it.
            rm -fv $package_install_dir$prefix/lib/libevent*.la
            # A system gets the core, the event loop and its buffers. The other libraries (the
            # whole, the network protocols and the support for POSIX threads) go with the
            # development files, as does the generator of RPC code, a Python script.
            move_to_dev_component usr/bin/event_rpcgen.py 'usr/lib/libevent-*.so.*' \
                'usr/lib/libevent_extra-*.so.*' 'usr/lib/libevent_pthreads-*.so.*'
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
