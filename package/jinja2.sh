: ${package_version:=3.1.6}
: ${package_source:=https://github.com/pallets/jinja/archive/refs/tags/$package_version.tar.gz}

# Repo (and therefore tarball top-level dir) is named "jinja", not "jinja2".
package_source_dir=$SOURCE_DIR/jinja-$package_version

install() {
    local site_packages=$package_install_dir$prefix/lib/python$(python3 -c 'import sysconfig; print(sysconfig.get_python_version())')/site-packages

    mkdir -pv $site_packages
    cp -rv $package_source_dir/src/jinja2 $site_packages/
}
