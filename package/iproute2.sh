: ${package_version:=7.0.0}
: ${package_source:=https://www.kernel.org/pub/linux/utils/net/iproute2/iproute2-$package_version.tar.xz}

: ${prefix:=/usr}

build() {
    make -C $package_source_dir \
        CC=$target-gcc \
        CROSS_COMPILE=$target-
}

install() {
    make -C $package_source_dir \
        CC=$target-gcc \
        CROSS_COMPILE=$target- \
        DESTDIR=$package_install_dir \
        PREFIX=$prefix \
        SBINDIR=/usr/sbin \
        CONFDIR=/etc/iproute2 \
        DOCDIR=/usr/share/doc/iproute2-$package_version \
        install
}
