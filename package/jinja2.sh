: ${package_version:=3.1.6}
: ${package_source:=https://github.com/pallets/jinja/archive/$package_version/jinja-$package_version.tar.gz}
: ${package_source_hash:=sha256:2074b22a72caa65474902234b320d73463d6d4c223ee49f4b433495758356337}
: ${package_description:=Python templating engine.}
: ${package_license:=BSD-3-Clause}

# Repo (and therefore tarball top-level dir) is named "jinja", not "jinja2".
package_source_dir=$SOURCE_DIR/jinja-$package_version

install() {
    local site_packages=$package_install_dir$prefix/lib/python${python_version%.*}/site-packages

    mkdir -pv $site_packages
    cp -rv $package_source_dir/src/jinja2 $site_packages/
}
