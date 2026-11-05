: ${package_version:=1.13.2}
: ${package_source:=https://github.com/ninja-build/ninja/archive/v$package_version/ninja-$package_version.tar.gz}
: ${package_source_hash:=sha256:974d6b2f4eeefa25625d34da3cb36bdcebe7fbce40f4c16ac0835fd1c0cbae17}
: ${package_description:=Small build system focused on speed.}
: ${package_license:=Apache-2.0}

build() {
    cd $package_source_dir
    python3 configure.py --bootstrap
}

install() {
    mkdir -pv $package_install_dir$prefix/bin
    # use `command` to run the coreutils program instead of calling this function recursively.
    command install -v -m755 $package_source_dir/ninja $package_install_dir$prefix/bin/ninja
}
