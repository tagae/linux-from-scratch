: ${package_version:=6.17.1}
: ${package_source:=https://www.kernel.org/pub/linux/kernel/people/kdave/btrfs-progs/btrfs-progs-v$package_version.tar.xz}
: ${package_source_hash:=sha256:a4be0a6ebb3c476427fb5d97b2cf027b0ccdb6b0c55ff16323320c1e8cb77658}

package_source_dir=$SOURCE_DIR/btrfs-progs-v$package_version

# Only need mkfs.btrfs and the btrfs CLI (subvolume create) for image
# creation — disable everything else optional so we don't need zstd/lzo
# (compression backends), libudev (multipath support), python
# (libbtrfsutil bindings), or libext2fs/e2fsprogs (btrfs-convert, for
# converting an existing ext2/3/4 filesystem in place — we only ever
# format a fresh one).
# Hand-rolled configure/Makefile, not full autoconf — no out-of-tree build
# support, so run every step directly in package_source_dir.
#
# Note: this in-tree build model (package_source_dir hardcoded above,
# reused directly as the build dir) means this package is NOT safe to
# build for two different scenarios back to back without a clean rebuild
# in between (e.g. build_tools()'s own build-host-native "tools" variant
# vs. a target "virt" variant) — `make`'s own dependency tracking can see
# already-compiled objects from the OTHER variant's run
# and skip recompiling, silently installing stale, wrong-toolchain
# binaries (confirmed the hard way: a target build produced a binary whose
# ELF interpreter was still TOOL_DIR-relative). Every other package in
# this project avoids this by building out-of-tree in its own variant-
# scoped package_build_dir; this one can't (no out-of-tree support
# upstream). `rm -rf source/btrfs-progs-v$package_version` before
# switching scenarios is the workaround.
prepare() {
    cd $package_source_dir

    # libuuid/libblkid (uuid/uuid.h, blkid.h) come from util-linux, already
    # installed into the target tree earlier in the same umbrella — needs
    # the sysroot CC (target_sysroot_cc) to find them, same reasoning as
    # util-linux's own script; a no-op in the build-host-native reuse
    # (build_tools()), where host != $target.
    target_sysroot_cc

    ./configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-static \
        --disable-documentation \
        --disable-zstd \
        --disable-lzo \
        --disable-libudev \
        --disable-python \
        --disable-convert
}

build() {
    make -C $package_source_dir
}

install() {
    make -C $package_source_dir install DESTDIR=$package_install_dir
}
