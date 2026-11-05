: ${package_version:=2.9.0.post0}
: ${package_source:=https://files.pythonhosted.org/packages/source/p/python-dateutil/python-dateutil-$package_version.tar.gz}
: ${package_source_hash:=sha256:37dd54208da7e1cd875388217d5e00ebd4179249f90fb72437e91a35459a0ad3}
: ${package_description:=Extensions to the date and time module of Python.}
: ${package_license:=BSD-3-Clause AND Apache-2.0}

package_source_dir=$SOURCE_DIR/python/python-dateutil-$package_version

install() {
    local site_packages=$package_install_dir$prefix/lib/python${python_version%.*}/site-packages

    mkdir -pv $site_packages
    cp -rv $package_source_dir/src/dateutil $site_packages/
    python_compile
}
