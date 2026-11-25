: ${package_version:=4.11.0}
: ${package_source:=https://ftp.gnu.org/gnu/findutils/findutils-$package_version.tar.xz}
: ${package_source_hash:=sha256:bfd19cb06cc71f3352d567e90284d8cdac02ac89774bbeadf0b533b0c11432fd}
: ${package_description:=GNU file search utilities.}
: ${package_license:=GPL-3.0-or-later}
: ${package_cpe:=a:gnu:findutils:$package_version}

prepare() {
    case $package_component in
        findutils)
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${localstatedir:+--localstatedir=$localstatedir} \
                ${nls:+--enable-nls=$nls}
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        findutils)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        findutils)
            make install DESTDIR=$package_install_dir
            # locate searches a database of file names, which updatedb writes and no system keeps.
            rm -v $package_install_dir$prefix/bin/locate $package_install_dir$prefix/bin/updatedb \
                $package_install_dir$prefix/libexec/frcode
            rm -fv $package_install_dir$prefix/share/man/man1/locate.1 \
                $package_install_dir$prefix/share/man/man1/updatedb.1 \
                $package_install_dir$prefix/share/man/man5/locatedb.5
            find $package_install_dir -type d -empty -delete
            move_to_docs_component
            ;;
        *)
            default_install
            ;;
    esac
}
