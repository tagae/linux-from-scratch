: ${package_version:=0.14.3}
# archive/<ref>/<name>.tar.gz so the download is named multipath-tools-<v>.tar.gz,
# not a bare <v>.tar.gz: GitHub names the archive after the URL's last path
# component, and get() (lib/base.sh) derives the extract dir from that
# filename — so it must match the dir GitHub actually extracts to
# (multipath-tools-<v>). Other GitHub-sourced packages cite this note.
: ${package_source:=https://github.com/opensvc/multipath-tools/archive/$package_version/multipath-tools-$package_version.tar.gz}
: ${package_source_hash:=sha256:206ab1635b09309974e2fdf3bbd1825254638dc9b3d2bbd436d1105cd518d379}

# multipath-tools is a suite; this project builds only its self-contained
# kpartx tool, exposed as the `kpartx` component (install
# multipath-tools#kpartx) — mirroring gcc#libstdc++ / linux#headers, where
# one source set yields a named sub-component. The multipathd daemon and
# the rest pull in libaio/liburcu/readline/json-c/systemd we don't want, so
# any other component (including the bare suite) bails.
#
# No package_source_dir override is needed: named for the suite, it now
# defaults correctly to the extracted multipath-tools-$package_version dir.
case ${package_component:-} in
    kpartx) ;;
    *) bail "multipath-tools: only the 'kpartx' component is supported (got '${package_component:-}')" ;;
esac

# kpartx's own Makefile only depends on libdevmapper, so build just that
# subdirectory. It still needs the top-level config.mk generated first
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
