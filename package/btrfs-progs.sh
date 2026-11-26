: ${package_version:=7.1}
: ${package_source:=https://www.kernel.org/pub/linux/kernel/people/kdave/btrfs-progs/btrfs-progs-v$package_version.tar.xz}
: ${package_source_hash:=sha256:d1f55cc2971398c9142eaa79d203e63d586a3b4b867f956664a1d68322cd4e34}
: ${package_description:=Btrfs filesystem utilities.}
: ${package_license:=GPL-2.0-only AND LGPL-2.1-or-later AND BSD-2-Clause AND BSD-3-Clause AND (CC0-1.0 OR OpenSSL OR Apache-2.0)}
# The NVD names no product for it.
: ${package_cpe:=none}

package_source_dir=$source_dir/btrfs-progs-v$package_version

prepare() {
    # The Makefile only builds in the tree configure ran in, so build from a copy of the source.
    cp -Rp $package_source_dir/. .

    # The programs alone: they carry libbtrfsutil linked into them, and nothing else uses the
    # libraries.
    # With freedesktop's sysroot rules (CONTRIBUTING.md, Cross-Compiling), configure reads udev.pc's
    # directory as the place that the udev rules are installed in, for a system with udev.
    env PKG_CONFIG_FDO_SYSROOT_RULES=1 ./configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --disable-shared \
        --disable-static \
        --disable-documentation \
        --disable-zstd \
        --disable-lzo \
        --disable-libudev \
        --disable-python \
        --disable-convert
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir

    # The release ships its manual pages ready-made, which the Makefile installs only after making
    # them anew, with Sphinx.
    local section
    for section in 2 5 8; do
        mkdir -pv $package_install_dir$prefix/share/man/man$section
        cp -v $package_source_dir/Documentation/*.$section \
            $package_install_dir$prefix/share/man/man$section/
    done
    move_to_docs_component
}
