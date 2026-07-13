: ${package_version:=3.0.2}
# archive/<ref>/<name>.tar.gz so the download is markupsafe-<v>.tar.gz, not a
# bare <v>.tar.gz — see kpartx.sh for why.
: ${package_source:=https://github.com/pallets/markupsafe/archive/$package_version/markupsafe-$package_version.tar.gz}

package_source_dir=$SOURCE_DIR/markupsafe-$package_version

# Pure-Python fallback only: _speedups.c is a C accelerator markupsafe's
# own __init__.py already falls back from on ImportError, so there's no
# need to compile it just to generate a few templated files at build time.
install() {
    local site_packages=$package_install_dir$prefix/lib/python$(python3 -c 'import sysconfig; print(sysconfig.get_python_version())')/site-packages

    mkdir -pv $site_packages
    cp -rv $package_source_dir/src/markupsafe $site_packages/
}
