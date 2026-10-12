: ${package_version:=34.2}
: ${package_source:=https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-$package_version.tar.xz}
: ${package_source_hash:=sha256:5a5d5073070cc7e0c7a7a3c6ec2a0e1780850c8b47b3e3892226b93ffcb9cb54}
: ${package_description:=Kernel module management tools and library.}
: ${package_license:=GPL-2.0-or-later AND LGPL-2.1-or-later}

# Empty completion directories install no shell completions.
prepare() {
    case $package_component in
        kmod)
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                --sysconfdir=/etc \
                --with-bashcompletiondir= \
                --with-fishcompletiondir= \
                --with-zshcompletiondir= \
                ${openssl:+--with-openssl=$openssl} \
                ${xz:+--with-xz=$xz} \
                ${zstd:+--with-zstd=$zstd} \
                ${zlib:+--with-zlib=$zlib} \
                ${manpages:+--enable-manpages=$manpages}
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        kmod)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        kmod)
            make install DESTDIR=$package_install_dir
            split_dev_files
            ;;
        dev)
            install_split
            ;;
        *)
            default_install
            ;;
    esac
}
