# Rust toolchain — build-host-only BUILD SEED for Rust packages (fish):
# prebuilt rustc/cargo/std from static.rust-lang.org, hash-pinned and
# cross-checked against upstream's published .sha256 manifests. Never
# part of any target tree — fish.sh's depends() installs it under the
# tools scenario into $TOOL_DIR, exactly like cmake. Same seed category
# as the Debian bootstrap container's own apt gcc: build tooling whose
# OUTPUT (a fish binary compiled against OUR glibc and linked by OUR
# cross gcc) is what ships, never the tool itself. (Building rustc from
# source requires a prior rustc — a bootstrap-chain undertaking of its
# own, not one package's remit.)
#
# Component tarballs, not the combined "rust-" bundle (which drags in
# docs and more): rustc + cargo + the build host's own std, plus std for
# the arm cross target (pi0's armv6+vfpv2 hard-float is exactly Rust's
# arm-unknown-linux-gnueabihf). The aarch64 cross target needs no extra
# std — the host toolchain's own (same triple) serves it.
: ${package_version:=1.97.1}

# Only the aarch64 build host is pinned; extending to another host arch
# means adding its dist tarball hashes here.
case "$(uname -m)" in
    aarch64|arm64) ;;
    *) bail "rust: no pinned toolchain for build host $(uname -m) (add its dist hashes to package/rust.sh)" ;;
esac

fetch() {
    get https://static.rust-lang.org/dist/rustc-$package_version-aarch64-unknown-linux-gnu.tar.xz \
        sha256:b344b81f0cd4c2246c7da8b197fe7a339d7dd02bb15cb69b2524115d9c75224c
    get https://static.rust-lang.org/dist/cargo-$package_version-aarch64-unknown-linux-gnu.tar.xz \
        sha256:8f70bcaccea5ba4db187c3fd4d64e24592b4e16af513497201f5909d61691dbe
    get https://static.rust-lang.org/dist/rust-std-$package_version-aarch64-unknown-linux-gnu.tar.xz \
        sha256:46aed8e63186350004d8ec6afca798811e6530b514352e5a8a26f3dc4939b3be
    get https://static.rust-lang.org/dist/rust-std-$package_version-arm-unknown-linux-gnueabihf.tar.xz \
        sha256:5b1a03e3f6b021b2bc288a98011e1174a527922dbf4ece64d299472cf87b9cac
}

install() {
    # Each dist tarball ships its own install.sh (plain POSIX sh + core
    # utilities); --destdir/--prefix land everything under the tools
    # scenario's $TOOL_DIR/usr, where rustc finds the per-target std
    # sysroots (usr/lib/rustlib/<triple>) on its own.
    for _dist in rustc-$package_version-aarch64-unknown-linux-gnu \
                 cargo-$package_version-aarch64-unknown-linux-gnu \
                 rust-std-$package_version-aarch64-unknown-linux-gnu \
                 rust-std-$package_version-arm-unknown-linux-gnueabihf; do
        sh $SOURCE_DIR/$_dist/install.sh \
            --destdir=$package_install_dir \
            --prefix=/usr \
            --disable-ldconfig
    done
}
