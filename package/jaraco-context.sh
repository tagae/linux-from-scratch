: ${package_version:=6.1.2}
: ${package_source:=https://files.pythonhosted.org/packages/source/j/jaraco.context/jaraco_context-$package_version.tar.gz}
: ${package_source_hash:=sha256:f1a6c9d391e661cc5b8d39861ff077a7dc24dc23833ccee564b234b81c82dfe3}
: ${package_description:=Context managers for Python.}
: ${package_license:=MIT}

package_source_dir=$SOURCE_DIR/jaraco_context-$package_version

install() {
    local site_packages=$package_install_dir$prefix/lib/python${python_version%.*}/site-packages

    mkdir -pv $site_packages
    cp -rv $package_source_dir/jaraco $site_packages/
    python_compile
}
