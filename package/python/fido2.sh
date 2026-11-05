: ${package_version:=2.2.1}
: ${package_source:=https://files.pythonhosted.org/packages/source/f/fido2/fido2-$package_version.tar.gz}
: ${package_source_hash:=sha256:85787428a94c3f8eaf72f0ff30afba983b559a1b1b795c93318c81b4ad4062c4}
: ${package_description:=Python library to talk to FIDO2 authenticators.}
: ${package_license:=BSD-2-Clause AND Apache-2.0 AND MPL-2.0}

install() {
    python_install_modules $package_source_dir/fido2
}
