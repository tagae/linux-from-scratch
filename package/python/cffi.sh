: ${package_version:=2.1.1}
: ${package_source:=https://files.pythonhosted.org/packages/source/c/cffi/cffi-$package_version.tar.gz}
: ${package_source_hash:=sha256:dd31f52ea1086513bb9df30f8fcee9b8918323ae067a3d5b78bc826a000712be}
: ${package_description:=Foreign function interface for Python calling C code.}
: ${package_license:=MIT-0}

package_source_dir=$SOURCE_DIR/cffi-$package_version

build() {
    python_wheel
}

install() {
    python_install_wheel
}
