: ${package_version:=1.9.1}
: ${package_source:=https://github.com/mesonbuild/meson/releases/download/$package_version/meson-$package_version.tar.gz}
: ${package_source_sha256:=4e076606f2afff7881d195574bddcd8d89286f35a17b4977a216f535dc0c74ac}

# Pure-Python, no build step. setuptools isn't available for our python3
# build, so a plain setup.py install won't work — copy the package and its
# entry-point script into place directly instead, matching what pip itself
# would produce anyway (meson.py falls back to importing mesonbuild via
# sys.path when it isn't a sibling directory, so splitting them like this
# across bin/ and site-packages/ is fine).
install() {
    local site_packages=$package_install_dir$prefix/lib/python$(python3 -c 'import sysconfig; print(sysconfig.get_python_version())')/site-packages

    mkdir -pv $site_packages
    cp -rv $package_source_dir/mesonbuild $site_packages/

    mkdir -pv $package_install_dir$prefix/bin
    cp -v $package_source_dir/meson.py $package_install_dir$prefix/bin/meson
    chmod -v 755 $package_install_dir$prefix/bin/meson
}
