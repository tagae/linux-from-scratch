# fish — the friendly interactive shell. Optional add-on package like
# ncdu/the gnupg family: not part of any bootable-* umbrella, installed
# on demand into a platform's target tree with `./lfs install fish` (a
# systemd flavor — fish is dynamically linked against glibc, which the
# static busybox flavor lacks).
#
# fish 4.x is Rust. cargo compiles the crates with the pinned prebuilt
# SEED toolchain (package/rust.sh — build tooling only, like cmake); all
# C compilation (pcre2-sys's bundled PCRE2, build-script feature probes)
# and the final link go through OUR cross gcc with the target sysroot,
# so the shipped binary runs against this project's own glibc. CMake
# (fish's official build orchestrator) drives cargo and installs the
# share/ tree. Crate dependencies are fetched by cargo at build time and
# verified against the sha256 pins in the release tarball's committed
# Cargo.lock — the same integrity contract as package_source_hash, with
# upstream holding the pin list.
: ${package_version:=4.8.1}
: ${package_source:=https://github.com/fish-shell/fish-shell/releases/download/$package_version/fish-$package_version.tar.xz}
: ${package_source_hash:=sha256:0eb86a851e865e934a7c2091a73d7695225e78f0e00a7bb96d5f877d76c65782}

: ${build:=$(gcc -dumpmachine)}
target_sysroot_cc

# Rust spells the cross target its own way (lib/platform's $ARCH names
# ours): pi0's armv6+vfpv2 hard-float is exactly Rust's
# arm-unknown-linux-gnueabihf.
case $ARCH in
    arm64) rust_target=aarch64-unknown-linux-gnu ;;
    arm)   rust_target=arm-unknown-linux-gnueabihf ;;
    *)     bail "fish: no Rust target mapping for ARCH=$ARCH" ;;
esac

# Cross plumbing for cargo and the cc crate, exported here (script scope)
# so every _once step subshell sees it:
#  - the linker for the Rust target is OUR cross gcc; the sysroot/-L
#    flags CC carries (target_sysroot_cc) travel as rustc link-args,
#    scoped to the cross target so build scripts still link natively.
#  - TARGET_CC/TARGET_CFLAGS: what the cc crate compiles target C with
#    (pcre2-sys's bundled PCRE2, rsconf's feature probes); HOST_CC keeps
#    build-script host compiles on the native gcc (no bare `cc` exists in
#    the scratch container).
#  - CARGO_HOME in the work volume: the crate cache persists across
#    builds, so a warm rebuild needs no network.
#  - CARGO_HTTP_CAINFO: crates.io TLS verified against OUR CA bundle
#    (the same SSL_CERT_FILE contract as fetch_url).
_rust_target_env=$(printf %s "$rust_target" | tr 'a-z-' 'A-Z_')
export "CARGO_TARGET_${_rust_target_env}_LINKER=$target-gcc"
export "CARGO_TARGET_${_rust_target_env}_RUSTFLAGS=-C link-arg=--sysroot=$INSTALL_DIR/$SYSTEM_KEY -C link-arg=-L$INSTALL_DIR/$SYSTEM_KEY/usr/lib"
export TARGET_CC=$target-gcc
export TARGET_CFLAGS="--sysroot=$INSTALL_DIR/$SYSTEM_KEY"
export HOST_CC=gcc
export CARGO_HOME=$WORK_DIR/cargo-home
export CARGO_HTTP_CAINFO=$SSL_CERT_FILE

# Cargo also compiles build-script/proc-macro crates (rsconf, generic-
# array, ...) for its OWN host triple (aarch64-unknown-linux-gnu —
# rust.sh's only pinned build host) — a rustc invocation separate from
# the target triple above whenever the two differ, which they do for
# every arm platform (pi0: arm-unknown-linux-gnueabihf). Left unset,
# rustc's default linker name for that triple is bare `cc`, which
# doesn't exist in this container (the same gap HOST_CC works around
# for the cc crate's own C compiles — but HOST_CC never reaches rustc's
# own link step). Skipped when the triples already coincide (virt,
# ARCH=arm64): the target-triple override above already governs host
# compiles too there, and must win since it also carries the sysroot
# link-args.
if [ "$rust_target" != aarch64-unknown-linux-gnu ]; then
    export CARGO_TARGET_AARCH64_UNKNOWN_LINUX_GNU_LINKER=gcc
fi

depends() {
    # Build-host tools — the tools scenario, exactly the shape
    # lib/tools.sh's members use: an explicit package_install_dir
    # suppresses target_build_env (see install() in lib/package.sh), and
    # clearing package_merge_dir keeps _install from archiving/merging
    # HOST tools into the target image. CC/CXX (exported by
    # target_sysroot_cc above, pointing at the CROSS compiler) must not
    # leak into cmake's native bootstrap; host/build likewise.
    (
        unset package_merge_dir CC CXX host build
        package_variant=tools
        package_install_dir=$TOOL_DIR
        prefix=/usr
        require cmake
        require rust
    )
}

prepare() {
    # CC (the sysroot'd cross compiler, from target_sysroot_cc) comes
    # from the environment for cmake's own C feature checks;
    # CMAKE_SYSTEM_NAME=Linux puts cmake in cross mode (no try_run).
    # Bundled PCRE2 (FISH_USE_SYSTEM_PCRE2=OFF): pcre2-sys compiles its
    # own copy with TARGET_CC above and links it statically — one code
    # path on every platform, no cross pkg-config plumbing. No message
    # localization and no docs (project policy; the release tarball
    # ships prebuilt man pages, which Install.cmake copies as data).
    cmake $package_source_dir \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX=$prefix \
        -DCMAKE_SYSTEM_NAME=Linux \
        -DRust_CARGO_TARGET=$rust_target \
        -DFISH_USE_SYSTEM_PCRE2=OFF \
        -DWITH_MESSAGE_LOCALIZATION=OFF \
        -DWITH_DOCS=OFF
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
