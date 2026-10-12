: ${package_version:=7.3}
: ${package_source:=https://ftp.gnu.org/gnu/texinfo/texinfo-$package_version.tar.xz}
: ${package_source_hash:=sha256:51f74eb0f51cfa9873b85264dfdd5d46e8957ec95b88f0fb762f63d9e164c72e}
: ${package_description:=GNU Info reader and install-info.}
: ${package_license:=GPL-3.0-or-later}

# Only the Info reader and its index tool are built, not the Perl programs that turn Texinfo into
# documents (texi2any...). When cross compiling, configure builds the program that generates the
# reader's command table (makedoc) natively first, in the tools subdirectory, with BUILD_CC. That
# configure runs without TMPDIR, so it reports being unable to set up dependency tracking, which
# doesn't affect the build.
prepare() {
    case $package_component in
        texinfo)
            env BUILD_CC=gcc BUILD_AR=ar BUILD_RANLIB=ranlib \
                $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${nls:+--enable-nls=$nls} \
                --disable-perl-xs
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        texinfo)
            [ -z "${host:-}" ] || { make -C tools/gnulib/lib && make -C tools/info makedoc; }
            make -C gnulib/lib
            make -C info
            make -C install-info
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        texinfo)
            make -C info install DESTDIR=$package_install_dir
            make -C install-info install DESTDIR=$package_install_dir
            move_to_docs_component
            ;;
        *)
            default_install
            ;;
    esac
}
