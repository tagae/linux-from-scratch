: ${package_version:=3.4.0}
: ${package_source:=https://files.pythonhosted.org/packages/source/j/jaraco.classes/jaraco.classes-$package_version.tar.gz}
: ${package_source_hash:=sha256:47a024b51d0239c0dd8c8540c6c7f484be3b8fcf0b2d85c13825780d3b3f3acd}
: ${package_description:=Utility classes and meta-classes for Python.}
: ${package_license:=MIT}

package_source_dir=$SOURCE_DIR/python/jaraco.classes-$package_version

install() {
    python_install_modules $package_source_dir/jaraco
}
