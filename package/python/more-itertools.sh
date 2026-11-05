: ${package_version:=11.2.1}
: ${package_source:=https://files.pythonhosted.org/packages/source/m/more-itertools/more_itertools-$package_version.tar.gz}
: ${package_source_hash:=sha256:cbf08fd0af284dc69718b9b76a8e6203df624d70209ea511e4219d350c856f63}
: ${package_description:=More routines for operating on iterables.}
: ${package_license:=MIT}

package_source_dir=$SOURCE_DIR/python/more_itertools-$package_version

install() {
    python_install_modules $package_source_dir/more_itertools
}
