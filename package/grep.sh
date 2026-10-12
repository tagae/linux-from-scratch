: ${package_version:=3.12}
: ${package_source:=https://ftp.gnu.org/gnu/grep/grep-$package_version.tar.xz}
: ${package_source_hash:=sha256:2649b27c0e90e632eadcd757be06c6e9a4f48d941de51e7c0f83ff76408a07b9}
: ${package_description:=GNU pattern matching utilities.}
: ${package_license:=GPL-3.0-or-later}

prepare() {
    case $package_component in
        grep)
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${nls:+--enable-nls=$nls}
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        grep)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        grep)
            make install DESTDIR=$package_install_dir
            move_to_docs_component
            ;;
        *)
            default_install
            ;;
    esac
}
