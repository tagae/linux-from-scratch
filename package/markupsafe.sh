: ${package_version:=3.0.2}
: ${package_source:=https://github.com/pallets/markupsafe/archive/$package_version/markupsafe-$package_version.tar.gz}
: ${package_source_hash:=sha256:cd182103704bfafefce25369fd27f14a5f578f078b7f3ddd1ce2cb940b86403a}
: ${package_description:=Python library for HTML-safe string escaping.}
: ${package_license:=BSD-3-Clause}

package_source_dir=$SOURCE_DIR/markupsafe-$package_version

install() {
    local site_packages=$package_install_dir$prefix/lib/python${python_version%.*}/site-packages

    mkdir -pv $site_packages
    cp -rv $package_source_dir/src/markupsafe $site_packages/
}
