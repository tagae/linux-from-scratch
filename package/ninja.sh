: ${package_version:=1.13.1}
# archive/<ref>/<name>.tar.gz so the download is ninja-<v>.tar.gz, not a bare
# v<v>.tar.gz — see kpartx.sh for why. (Tag is v<v>; GitHub strips the v from
# the extracted dir, so name the file ninja-<v> to match.)
: ${package_source:=https://github.com/ninja-build/ninja/archive/v$package_version/ninja-$package_version.tar.gz}

# --bootstrap compiles ninja from nothing (no ninja needed to build ninja):
# it invokes the compiler directly per source file, then uses the resulting
# binary to rebuild itself properly. Plain c++/g++ on PATH already resolves
# to our own toolchain here (same convention as gettext/bison/python).
build() {
    cd $package_source_dir
    python3 configure.py --bootstrap
}

install() {
    mkdir -pv $package_install_dir$prefix/bin
    # command, not a bare call: this function is itself named "install",
    # so an unqualified call would recurse into itself instead of running
    # the actual coreutils program.
    command install -v -m755 $package_source_dir/ninja $package_install_dir$prefix/bin/ninja
}
