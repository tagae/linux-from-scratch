: ${package_version:=8.5.0}
: ${package_source:=https://files.pythonhosted.org/packages/source/c/click/click-$package_version.tar.gz}
: ${package_source_hash:=sha256:ba0d2089de75ea0310e2dde03160e6ca10009947fb95a182f9b54021bb272e34}
: ${package_description:=Python library to write command line interfaces.}
: ${package_license:=BSD-3-Clause}

install() {
    python_install_modules $package_source_dir/src/click
}
