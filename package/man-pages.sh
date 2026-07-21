: ${package_version:=6.18}
: ${package_source:=https://www.kernel.org/pub/linux/docs/man-pages/man-pages-$package_version.tar.xz}
: ${package_source_hash:=sha256:c934fadc8b59748c68227a34f6581d2ddf8282b73cdcd52546c8cd88b74b24d1}

install() {
    make -C $package_source_dir install ${prefix:+prefix=$package_install_dir/$prefix}
}
