: ${package_version:=3.11}
: ${package_source:=https://files.pythonhosted.org/packages/source/p/pycparser/pycparser-$package_version.tar.gz}
: ${package_source_hash:=sha256:d875f09c3507d00e1aba0eecc6dcadc1352f30fff09dc6bff2f1c2935e97c2bc}
: ${package_description:=C parser in Python.}
: ${package_license:=BSD-3-Clause}

install() {
    python_install_modules $package_source_dir/pycparser
}
