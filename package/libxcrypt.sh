: ${package_version:=4.5.2}
: ${package_source:=https://github.com/besser82/libxcrypt/releases/download/v$package_version/libxcrypt-$package_version.tar.xz}
: ${package_source_hash:=sha256:71513a31c01a428bccd5367a32fd95f115d6dac50fb5b60c779d5c7942aec071}
: ${package_description:=Extended crypt library for password hashing.}
: ${package_license:=LGPL-2.1-or-later AND BSD-3-Clause AND BSD-2-Clause AND 0BSD}

prepare() {
    case $package_component in
        libxcrypt)
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${hashes:+--enable-hashes=$hashes} \
                ${obsolete_api:+--enable-obsolete-api=$obsolete_api} \
                ${failure_tokens:+--enable-failure-tokens=$failure_tokens} \
                --disable-static \
                --disable-werror
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        libxcrypt)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        libxcrypt)
            make install DESTDIR=$package_install_dir
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
