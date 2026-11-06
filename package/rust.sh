: ${package_version:=1.97.1}
: ${package_description:=Rust compiler and package manager (Cargo), with the standard library for the platforms.}
: ${package_license:=MIT OR Apache-2.0}

# Compiling Rust takes a Rust compiler, so this one comes prebuilt by the Rust project, as a seed
# that stays on the build machine: rustc and cargo, the standard library for the build machine,
# where build scripts and procedural macros run, and the platform's, when the platform's target is
# another. Only an aarch64 build machine is pinned.
case $(uname -m) in
    aarch64|arm64) rust_host=aarch64-unknown-linux-gnu ;;
    *) bail "No Rust toolchain pinned for a $(uname -m) build machine" ;;
esac

# The platform's target, as Rust names it.
rust_target=$target_arch-unknown-$target_kernel-$target_abi
rust_targets=$rust_host
[ $rust_target = $rust_host ] || rust_targets="$rust_targets $rust_target"

fetch() {
    get https://static.rust-lang.org/dist/rustc-$package_version-$rust_host.tar.xz \
        sha256:b344b81f0cd4c2246c7da8b197fe7a339d7dd02bb15cb69b2524115d9c75224c
    get https://static.rust-lang.org/dist/cargo-$package_version-$rust_host.tar.xz \
        sha256:8f70bcaccea5ba4db187c3fd4d64e24592b4e16af513497201f5909d61691dbe
    local target hash
    for target in $rust_targets; do
        case $target in
            aarch64-unknown-linux-gnu)
                hash=sha256:46aed8e63186350004d8ec6afca798811e6530b514352e5a8a26f3dc4939b3be ;;
            arm-unknown-linux-gnueabihf)
                hash=sha256:5b1a03e3f6b021b2bc288a98011e1174a527922dbf4ece64d299472cf87b9cac ;;
            *)
                bail "No Rust standard library pinned for $target" ;;
        esac
        get https://static.rust-lang.org/dist/rust-std-$package_version-$target.tar.xz $hash
    done
}

install() {
    local dist target
    for dist in rustc-$package_version-$rust_host cargo-$package_version-$rust_host \
                $(for target in $rust_targets; do echo rust-std-$package_version-$target; done); do
        sh $SOURCE_DIR/$dist/install.sh --destdir=$package_install_dir --prefix=$prefix \
            --disable-ldconfig
    done
    move_to_docs_component

    # The programs ask for the loader at /lib, where the build machine may have none: they run
    # through the loader of TOOL_DIR, with its libraries. rustc finds its own libraries from the
    # location of librustc_driver, in TOOL_DIR's lib.
    local rtld=$(find $TOOL_DIR$prefix/lib -maxdepth 1 -name 'ld-linux-*.so.*' | head -1)
    local bin=$package_install_dir$prefix/bin libexec=$package_install_dir$prefix/libexec
    mkdir -pv $libexec
    mv -v $bin/rustc $bin/cargo $libexec/
    cat > $bin/rustc <<EOF
#!/bin/sh
exec $rtld --library-path $TOOL_DIR$prefix/lib $TOOL_DIR$prefix/libexec/rustc "\$@"
EOF
    # Build scripts and procedural macros, which cargo builds for the build machine and runs, are
    # linked like the other programs of TOOL_DIR.
    cat > $bin/cargo <<EOF
#!/bin/sh
export CARGO_TARGET_$(echo $rust_host | tr a-z- A-Z_)_LINKER=$TOOL_DIR$prefix/libexec/cargo-linker
exec $rtld --library-path $TOOL_DIR$prefix/lib $TOOL_DIR$prefix/libexec/cargo "\$@"
EOF
    cat > $libexec/cargo-linker <<EOF
#!/bin/sh
exec $CC $LDFLAGS "\$@"
EOF
    chmod -v 755 $bin/rustc $bin/cargo $libexec/cargo-linker
}
