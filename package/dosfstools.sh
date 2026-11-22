: ${package_version:=4.2}
: ${package_source:=https://github.com/dosfstools/dosfstools/releases/download/v$package_version/dosfstools-$package_version.tar.gz}
: ${package_source_hash:=sha256:64926eebf90092dca21b14259a5301b7b98e7b1943e8a201c7d726084809b527}
: ${package_description:=FAT filesystem utilities.}
: ${package_license:=GPL-3.0-or-later}

prepare() {
    case $package_component in
        dosfstools)
            # Labels are converted to the DOS code page by a table of the programs' own. The systems
            # have no iconv modules, for which mkfs.fat would warn at every run.
            : ${iconv:=no}

            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${iconv:+--with-iconv=$iconv}
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        dosfstools)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        dosfstools)
            make install DESTDIR=$package_install_dir
            move_to_docs_component
            ;;
        *)
            default_install
            ;;
    esac
}
