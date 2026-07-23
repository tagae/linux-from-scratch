: ${package_version:=1.9.1}
: ${package_source:=https://github.com/mesonbuild/meson/releases/download/$package_version/meson-$package_version.tar.gz}
: ${package_source_hash:=sha256:4e076606f2afff7881d195574bddcd8d89286f35a17b4977a216f535dc0c74ac}

# Pure-Python, no build step. setuptools isn't available for our python3
# build, so a plain setup.py install won't work — copy the package and its
# entry-point script into place directly instead.
#
# Install meson.py alongside its own mesonbuild package in a dedicated,
# python-version-independent directory, with bin/meson a symlink into it.
# meson.py resolves its own realpath and, on finding mesonbuild as a sibling,
# imports it directly (see the check near the top of meson.py) — so it runs
# under ANY python, not only the one whose version-specific site-packages it
# was installed into. That is what lets meson be built once (in
# bootstrap_tools' cert chain, under the Debian container's python) yet also
# run in the scratch phase under our own, newer python; a site-packages
# install keyed to one version would break under the other.
install() {
    local meson_dir=$package_install_dir$prefix/lib/meson

    mkdir -pv $meson_dir
    cp -rv $package_source_dir/mesonbuild $meson_dir/
    cp -v $package_source_dir/meson.py $meson_dir/meson
    chmod -v 755 $meson_dir/meson

    mkdir -pv $package_install_dir$prefix/bin
    # Relative symlink so it resolves the same in-container regardless of where
    # $prefix is mounted; meson.py's realpath resolution then lands in
    # $prefix/lib/meson, where mesonbuild is its sibling.
    ln -sfv ../lib/meson/meson $package_install_dir$prefix/bin/meson
}
