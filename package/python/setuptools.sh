: ${package_version:=84.0.0}
: ${package_source:=https://files.pythonhosted.org/packages/source/s/setuptools/setuptools-$package_version.tar.gz}
: ${package_source_hash:=sha256:f4695c21257f0d9b537ec2692c941d02ee143b7cc1276941349a546573b2ef73}
: ${package_description:=Python library to build Python packages.}
: ${package_license:=MIT}

package_source_dir=$SOURCE_DIR/setuptools-$package_version

build() {
    python_wheel
}

install() {
    python_install_wheel
}
