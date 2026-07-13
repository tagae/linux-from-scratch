: ${package_version:=0.14.3}
# archive/<ref>/<name>.tar.gz form (not archive/refs/tags/<tag>.tar.gz): the
# latter makes the downloaded file just "<version>.tar.gz" — ambiguous in
# the shared download/ dir, and get() derives its "already extracted?" check
# from that name (multipath-tools-<v>, so it never matches → re-extracts
# every fetch). Naming it after the extracted dir fixes both.
: ${package_source:=https://github.com/opensvc/multipath-tools/archive/$package_version/multipath-tools-$package_version.tar.gz}

package_source_dir=$SOURCE_DIR/multipath-tools-$package_version

# kpartx is one self-contained tool within the broader multipath-tools
# suite (which also builds a multipathd daemon needing libaio/liburcu/
# readline/json-c/systemd — none of which we need). Its own Makefile only
# depends on libdevmapper, so build just this subdirectory rather than
# the whole suite. It still needs the top-level config.mk generated first
# (normally a side effect of building the top-level Makefile).
prepare() {
    make -C $package_source_dir -f create-config.mk
}

build() {
    make -C $package_source_dir/kpartx CC=gcc
}

install() {
    # Makefile.inc's own prefix defaults to empty (plain /bin, /sbin — no
    # usr merge), unlike everything else we build into TOOL_DIR.
    make -C $package_source_dir/kpartx install \
        DESTDIR=$package_install_dir CC=gcc prefix=${prefix:-/usr}
}
