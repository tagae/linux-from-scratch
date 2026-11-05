: ${package_version:=3.11}
: ${package_source:=https://files.pythonhosted.org/packages/source/p/pycparser/pycparser-$package_version.tar.gz}
: ${package_source_hash:=sha256:d875f09c3507d00e1aba0eecc6dcadc1352f30fff09dc6bff2f1c2935e97c2bc}
: ${package_description:=C parser in Python.}
: ${package_license:=BSD-3-Clause}

package_source_dir=$SOURCE_DIR/pycparser-$package_version

install() {
    local site_packages=$package_install_dir$prefix/lib/python${python_version%.*}/site-packages

    mkdir -pv $site_packages
    cp -rv $package_source_dir/pycparser $site_packages/
    python_compile
}
