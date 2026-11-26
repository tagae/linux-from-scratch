: ${package_version:=5.9.2}
: ${package_source:=https://files.pythonhosted.org/packages/source/y/yubikey-manager/yubikey_manager-$package_version.tar.gz}
: ${package_source_hash:=sha256:9584c7377449e6487140da6c3f13a289e618b0023c8414be91c1c212fce3c473}
: ${package_description:=Command line tool and Python library to configure a YubiKey.}
: ${package_license:=BSD-2-Clause}
# The library that writes ykman's bash completion.
: ${package_fetch_dependencies:=python/click}

package_source_dir=$source_dir/python/yubikey_manager-$package_version

install() {
    python_install_modules $package_source_dir/ykman $package_source_dir/yubikit

    # What the entry point of its project file would generate: a program that runs ykman's main.
    cd $package_install_dir
    cp -rv $package_files_dir/usr .

    mkdir -pv $package_install_dir$prefix/share/man/man1
    cp -v $package_source_dir/man/ykman.1 $package_install_dir$prefix/share/man/man1/

    # What `_YKMAN_COMPLETE=bash_source ykman` prints, which ykman(1) has a user save to complete
    # its arguments: click writes it from the program's name alone, here on the build machine.
    : ${bash_completion:=no}
    case $bash_completion in
        yes)
            mkdir -pv $package_install_dir$prefix/share/bash-completion/completions
            PYTHONPATH=$python_click_source_dir/src $LFS_TOOL_DIR/usr/bin/python3 -B -c '
from click.shell_completion import BashComplete
print(BashComplete(None, {}, "ykman", "_YKMAN_COMPLETE").source(), end="")
' > $package_install_dir$prefix/share/bash-completion/completions/ykman
            ;;
    esac
    move_to_docs_component
}
