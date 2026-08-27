: ${package_version:=1.13.1}
# archive/<ref>/<name>.tar.gz so the download is ninja-<v>.tar.gz, not a bare
# v<v>.tar.gz — see multipath-tools.sh for why. (Tag is v<v>; GitHub strips the v from
# the extracted dir, so name the file ninja-<v> to match.)
: ${package_source:=https://github.com/ninja-build/ninja/archive/v$package_version/ninja-$package_version.tar.gz}
: ${package_source_hash:=sha256:f0055ad0369bf2e372955ba55128d000cfcc21777057806015b45e4accbebf23}

# --bootstrap compiles ninja from nothing (no ninja needed to build ninja):
# it invokes the compiler directly per source file, then uses the resulting
# binary to rebuild itself properly. Plain c++/g++ on PATH already resolves
# to our own toolchain here (same convention as gettext/bison/python).
#
# CXX/AR: a target-scenario build (host=$target set by target_build_env,
# shipping this tool to the guest as an archive tarball) needs configure.py
# routed to the CROSS C++ compiler ($target-g++) instead — left alone, its
# own default ('c++'/'ar', both
# respected via env per configure.py's own env_keys) would resolve to this
# build host's bare native toolchain instead, producing a binary linked for
# the WRONG runtime (same architecture as virt, so this wouldn't fail
# outright, just silently link wrong — the same same-arch canary risk
# ncdu.sh/the gnupg family guard against). ${host:+$host-} is a no-op
# wherever host stays unset (every existing caller, including
# build_tools()'s own native `install ninja`), keeping bare c++/ar exactly
# as before. python3 itself is always this build host's own tools python —
# it only RUNS configure.py, the file it produces is target C++.
build() {
    cd $package_source_dir
    CXX=${host:+$host-}g++ AR=${host:+$host-}ar python3 configure.py --bootstrap
}

install() {
    mkdir -pv $package_install_dir$prefix/bin
    # command, not a bare call: this function is itself named "install",
    # so an unqualified call would recurse into itself instead of running
    # the actual coreutils program.
    command install -v -m755 $package_source_dir/ninja $package_install_dir$prefix/bin/ninja
}
