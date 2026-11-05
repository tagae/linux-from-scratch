: ${package_version:=8.5.0}
: ${package_source:=https://files.pythonhosted.org/packages/source/c/click/click-$package_version.tar.gz}
: ${package_source_hash:=sha256:ba0d2089de75ea0310e2dde03160e6ca10009947fb95a182f9b54021bb272e34}
: ${package_description:=Python library to write command line interfaces.}
: ${package_license:=BSD-3-Clause}

package_source_dir=$SOURCE_DIR/click-$package_version

install() {
    local site_packages=$package_install_dir$prefix/lib/python${python_version%.*}/site-packages

    mkdir -pv $site_packages
    cp -rv $package_source_dir/src/click $site_packages/
    python_compile
}
