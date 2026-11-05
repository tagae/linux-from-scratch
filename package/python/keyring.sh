: ${package_version:=25.7.0}
: ${package_source:=https://files.pythonhosted.org/packages/source/k/keyring/keyring-$package_version.tar.gz}
: ${package_source_hash:=sha256:fe01bd85eb3f8fb3dd0405defdeac9a5b4f6f0439edbb3149577f244a2e8245b}
: ${package_description:=Python library to store and read passwords in a secret store.}
: ${package_license:=MIT}

install() {
    python_install_modules $package_source_dir/keyring
}
