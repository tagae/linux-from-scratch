# Kernel module loading.

: ${package_version:=34.2}
: ${package_source:=https://www.kernel.org/pub/linux/utils/kernel/kmod/kmod-$package_version.tar.xz}
: ${package_source_sha256:=5a5d5073070cc7e0c7a7a3c6ec2a0e1780850c8b47b3e3892226b93ffcb9cb54}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${openssl:+--with-openssl=$openssl} \
        ${xz:+--with-xz=$xz} \
        ${zstd:+--with-zstd=$zstd} \
        ${zlib:+--with-zlib=$zlib} \
        ${manpages:+--enable-manpages=$manpages}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir

    for tool in depmod insmod modinfo modprobe rmmod; do
        ln -sfv kmod $package_install_dir/$prefix/bin/$tool
    done
    ln -sfv kmod $package_install_dir/$prefix/bin/lsmod
}
