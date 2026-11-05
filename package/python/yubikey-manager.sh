: ${package_version:=5.9.2}
: ${package_source:=https://files.pythonhosted.org/packages/source/y/yubikey-manager/yubikey_manager-$package_version.tar.gz}
: ${package_source_hash:=sha256:9584c7377449e6487140da6c3f13a289e618b0023c8414be91c1c212fce3c473}
: ${package_description:=Command line tool and Python library to configure a YubiKey.}
: ${package_license:=BSD-2-Clause}

package_source_dir=$SOURCE_DIR/python/yubikey_manager-$package_version

install() {
    python_install_modules $package_source_dir/ykman $package_source_dir/yubikit

    # What the entry point of its project file would generate: a program that runs ykman's main.
    cd $package_install_dir
    cp -rv $package_files_dir/usr .
}
