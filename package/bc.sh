: ${package_version:=7.0.3}
: ${package_source:=https://github.com/gavinhoward/bc/releases/download/$package_version/bc-$package_version.tar.xz}
: ${package_source_hash:=sha256:91eb74caed0ee6655b669711a4f350c25579778694df248e28363318e03c7fc4}

# Custom build system (configure.sh, not autoconf) — no --host/--build, so
# no build= guard (nothing here to disambiguate). But it also has no
# cross-compiler knob of its own, unlike autoconf's --host: CC is
# hardcoded, so a target-scenario build (SELF-HOST.md M3, host=$target set
# by target_build_env) would otherwise silently compile+link with THIS
# build host's own bare "gcc" instead of $target-gcc — same-arch (virt is
# aarch64, same as this build host), so it wouldn't fail outright, just
# link the wrong runtime. ${host:+$host-} is a no-op wherever host stays
# unset (every existing caller, including build_tools()'s own native
# `install bc` — package_install_dir preset there, so target_build_env
# never runs and host is never set), keeping bare "gcc" exactly as before.
prepare() {
    CC="${host:+$host-}gcc -std=c99" $package_source_dir/configure \
        ${prefix:+--prefix=$prefix} \
        -O3
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
