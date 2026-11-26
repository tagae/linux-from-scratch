: ${package_version:=1.11.5}
# Debian's orig tarball: the name of upstream's own archive of a tag is the version alone.
: ${package_source:=https://deb.debian.org/debian/pool/main/s/scdoc/scdoc_$package_version.orig.tar.xz}
: ${package_source_hash:=sha256:f494b538e1d92490026a9cdd40b58e3025553e69dd524f3f12befd6fb1e3ed27}
: ${package_description:=Generator of manual pages from a plain markup.}
: ${package_license:=MIT}

# scdoc builds in its source tree.
prepare() {
    cp -Rp $package_source_dir/. .
}

build() {
    make PREFIX=$prefix
}

install() {
    make install PREFIX=$prefix DESTDIR=$package_install_dir
    move_to_docs_component
}
