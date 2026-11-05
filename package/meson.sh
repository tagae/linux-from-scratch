: ${package_version:=1.12.0}
: ${package_source:=https://github.com/mesonbuild/meson/releases/download/$package_version/meson-$package_version.tar.gz}
: ${package_source_hash:=sha256:88afe0c20e52030218924ac37d0c81c59b4b5f3ae3752c8c6d7470c7d365886c}
: ${package_description:=Meson build system.}
: ${package_license:=Apache-2.0}

install() {
    local meson_dir=$package_install_dir$prefix/lib/meson

    mkdir -pv $meson_dir
    cp -rv $package_source_dir/mesonbuild $meson_dir/
    cp -v $package_source_dir/meson.py $meson_dir/meson
    chmod -v 755 $meson_dir/meson

    mkdir -pv $package_install_dir$prefix/bin
    ln -sfv ../lib/meson/meson $package_install_dir$prefix/bin/meson
}
