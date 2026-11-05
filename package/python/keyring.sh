: ${package_version:=25.7.0}
: ${package_source:=https://files.pythonhosted.org/packages/source/k/keyring/keyring-$package_version.tar.gz}
: ${package_source_hash:=sha256:fe01bd85eb3f8fb3dd0405defdeac9a5b4f6f0439edbb3149577f244a2e8245b}
: ${package_description:=Python library to store and read passwords in a secret store.}
: ${package_license:=MIT}

package_source_dir=$SOURCE_DIR/keyring-$package_version

install() {
    local site_packages=$package_install_dir$prefix/lib/python${python_version%.*}/site-packages

    mkdir -pv $site_packages
    cp -rv $package_source_dir/keyring $site_packages/
    python_compile
}
