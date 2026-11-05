: ${package_version:=1.17.0}
: ${package_source:=https://files.pythonhosted.org/packages/source/s/six/six-$package_version.tar.gz}
: ${package_source_hash:=sha256:ff70335d468e7eb6ec65b95b99d3a2836546063f63acc5171de367e834932a81}
: ${package_description:=Compatibility helpers for Python 2 and 3 code.}
: ${package_license:=MIT}

package_source_dir=$SOURCE_DIR/six-$package_version

install() {
    local site_packages=$package_install_dir$prefix/lib/python${python_version%.*}/site-packages

    mkdir -pv $site_packages
    cp -rv $package_source_dir/six.py $site_packages/
    python_compile
}
