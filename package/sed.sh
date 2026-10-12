: ${package_version:=4.10}
: ${package_source:=https://ftp.gnu.org/gnu/sed/sed-$package_version.tar.xz}
: ${package_source_hash:=sha256:b8e72182b2ec96a3574e2998c47b7aaa64cc20ce000d8e9ac313cc07cecf28c7}
: ${package_description:=GNU stream editor.}
: ${package_license:=GPL-3.0-or-later}

prepare() {
    case $package_component in
        sed)
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
        sed)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        sed)
            make install DESTDIR=$package_install_dir
            split_docs
            ;;
        docs)
            install_split
            ;;
        *)
            default_install
            ;;
    esac
}
