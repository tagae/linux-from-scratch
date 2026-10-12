: ${package_version:=3.0.2}
: ${package_source:=https://files.pythonhosted.org/packages/source/m/markupsafe/markupsafe-$package_version.tar.gz}
: ${package_source_hash:=sha256:ee55d3edf80167e48ea11a923c7386f4669df67d7994554387f84e7d8b0a2bf0}
: ${package_description:=Python library for HTML-safe string escaping.}
: ${package_license:=BSD-3-Clause}

install() {
    local site_packages=$package_install_dir$prefix/lib/python${python_version%.*}/site-packages

    mkdir -pv $site_packages
    cp -rv $package_source_dir/src/markupsafe $site_packages/
}
