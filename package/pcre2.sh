: ${package_version:=10.49}
: ${package_source:=https://github.com/PCRE2Project/pcre2/releases/download/pcre2-$package_version/pcre2-$package_version.tar.bz2}
: ${package_source_hash:=sha256:53c156e1ba416a20da8e65395daa132da0d80e76910424caca3fcdae7831d384}
: ${package_description:=Perl-compatible regular expression library.}
: ${package_license:=BSD-3-Clause WITH PCRE2-exception}
: ${package_cpe:=a:pcre:pcre2:$package_version}

prepare() {
    case $package_component in
        pcre2)
            # GLib matches UTF-8 text with Unicode properties: only the 8-bit library, with
            # Unicode support. The JIT compiler is of no use to it.
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                --enable-unicode \
                --disable-jit \
                --disable-pcre2-16 \
                --disable-pcre2-32 \
                --disable-static
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        pcre2)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        pcre2)
            make install DESTDIR=$package_install_dir
            cd $package_install_dir

            # The libtool archives make libtool put the sysroot in the run-time path of what links
            # against the libraries. The test program and the grep are of no use here.
            rm -fv usr/lib/*.la
            rm -v usr/bin/pcre2grep usr/bin/pcre2test \
                usr/share/man/man1/pcre2grep.1 usr/share/man/man1/pcre2test.1

            move_to_dev_component usr/bin/pcre2-config usr/share/man/man1/pcre2-config.1
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
