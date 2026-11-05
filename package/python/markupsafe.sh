: ${package_version:=3.0.3}
: ${package_source:=https://files.pythonhosted.org/packages/source/m/markupsafe/markupsafe-$package_version.tar.gz}
: ${package_source_hash:=sha256:722695808f4b6457b320fdc131280796bdceb04ab50fe1795cd540799ebe1698}
: ${package_description:=Python library for HTML-safe string escaping.}
: ${package_license:=BSD-3-Clause}

install() {
    python_install_modules $package_source_dir/src/markupsafe
}
