: ${package_version:=6.06}
: ${package_source:=https://www.kernel.org/pub/linux/docs/man-pages/man-pages-$package_version.tar.xz}

: ${prefix:=/usr}

install() {
    make -C $package_source_dir install prefix=$package_install_dir/$prefix
}
