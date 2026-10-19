: ${package_version:=4.6.0}
: ${package_source:=https://files.pythonhosted.org/packages/source/j/jaraco.functools/jaraco_functools-$package_version.tar.gz}
: ${package_source_hash:=sha256:880c577ec9720b3a052d5bc611fb9f2269b3d87902ef42440df443b88e443280}
: ${package_description:=Utility functions for Python functions.}
: ${package_license:=MIT}

package_source_dir=$SOURCE_DIR/jaraco_functools-$package_version

install() {
    local site_packages=$package_install_dir$prefix/lib/python${python_version%.*}/site-packages

    mkdir -pv $site_packages
    cp -rv $package_source_dir/jaraco $site_packages/
    python_compile
}
