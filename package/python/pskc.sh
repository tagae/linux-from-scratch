: ${package_version:=1.4}
: ${package_source:=https://files.pythonhosted.org/packages/source/p/python-pskc/python_pskc-$package_version.tar.gz}
: ${package_source_hash:=sha256:4a36381446ca067be728b30e01b4d18dbd9d1ad553bf07c3710abcd87653eefe}
: ${package_description:=Python library for portable symmetric key container (PSKC) files.}
: ${package_license:=LGPL-2.1-or-later}

package_source_dir=$SOURCE_DIR/python/python_pskc-$package_version

install() {
    local site_packages=$package_install_dir$prefix/lib/python${python_version%.*}/site-packages

    mkdir -pv $site_packages
    cp -rv $package_source_dir/pskc $site_packages/
    python_compile
}
