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
# binaries (confirmed the hard way, TWICE: a target build produced a
# binary whose ELF interpreter was still TOOL_DIR-relative — the second
# time from-pristine in `make e2e-test`'s E1, where the payload's target
# mkfs.btrfs shipped the container's rtld path into the builder image and
# exec'd ENOENT in the guest). Every other package in this project avoids
# this by building out-of-tree in its own variant-scoped
# package_build_dir; this one can't (no out-of-tree support upstream), so
# prepare() below cleans the tree before configuring — prepare is
# per-variant (stamped in the variant's own work dir), which makes the
# scenario switch self-healing instead of an operator-remembered rm.
prepare() {
    cd $package_source_dir

    # Purge the previous scenario's objects/binaries (see the in-tree
    # build note above). Keyed on Makefile.inc — the file configure
    # GENERATES — not the shipped top-level Makefile, which exists in the
    # pristine tarball and stops with "please configure first" if run:
    # Makefile.inc present is exactly "a prior configure ran here", the
    # only case where stale artifacts can exist at all.
    if [ -f Makefile.inc ]; then
        make clean
    fi

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
