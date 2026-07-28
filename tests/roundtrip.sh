#!/bin/sh

# tests/roundtrip.sh -- Tier 3: the PACKAGING.md "gold round trip" made
# automatic. For every archive/<key>/ that already has an ORDER (a prior
# `system build`), reconstruct a THROWAWAY merge tree purely by extracting
# archive/<key>/<tarball> in ORDER -- the same operation `./lfs unarchive`
# performs -- then diff it against the real install/<key>. tests/
# artifacts.sh's per-tarball checks catch the empty/truncated-tarball
# class cheaply; this is the acceptance test packaging.md itself
# describes: prove the tarballs actually RECONSTRUCT what's installed,
# not just that each one individually looks non-empty. A key with no
# archive/<key>/ORDER or no install/<key> SKIPs, same incremental-build
# convention as tests/artifacts.sh.
#
# Reconstructs under $WORK_DIR, never touches install/<key> itself, so a
# failed or interrupted run can't corrupt real build state (packaging.md's
# own manual version of this test wipes the live merge tree; this doesn't
# need to -- diffing a fresh scratch copy against it proves the same
# thing without the risk). No image build, no boot: Tier 4 (`make test`)
# already proves install/<key> itself boots, so a byte-identical
# reconstruction inherits that proof for free -- re-imaging and
# re-booting an identical tree would just be a slower way of re-asking a
# question this diff already answers.
#
#   docker compose run --rm scratch sh tests/roundtrip.sh

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$PROJECT_DIR/tests/tap.sh"

# Same /var/lfs-vs-$PROJECT_DIR detection as `lfs` itself (see tests/
# artifacts.sh for why getting this wrong makes every check below
# silently SKIP instead of running).
if [ -d /var/lfs ]; then
    _state=/var/lfs
else
    _state=$PROJECT_DIR
fi
: "${ARCHIVE_DIR:=$_state/archive}"
: "${INSTALL_DIR:=$_state/install}"
: "${WORK_DIR:=$_state/work}"

RECON_ROOT=$WORK_DIR/roundtrip-check
rm -rf "$RECON_ROOT"
mkdir -p "$RECON_ROOT"

found=0
if [ -d "$ARCHIVE_DIR" ]; then
    for dir in "$ARCHIVE_DIR"/*/; do
        [ -d "$dir" ] || continue
        key=$(basename "$dir")
        order_file=${dir}ORDER

        if [ ! -f "$order_file" ]; then
            continue
        fi
        found=$((found + 1))

        if [ ! -d "$INSTALL_DIR/$key" ]; then
            skip "roundtrip:$key" "install/$key not built (nothing to diff against)"
            continue
        fi

        recon=$RECON_ROOT/$key
        rm -rf "$recon"
        mkdir -p "$recon"

        # Extract every tarball in ORDER, in order -- exactly the
        # sequence default_merge applies during a real system build (see
        # packaging.md: extraction order matters for the handful of
        # deliberately-overlapping files, e.g. busybox's applet symlinks
        # vs. util-linux/systemd's real binaries).
        while IFS= read -r tarball; do
            [ -n "$tarball" ] || continue
            tar xf "$dir$tarball" -C "$recon"
        done < "$order_file"

        diff_log=$(mktemp "${TMPDIR:-/tmp}/lfs-roundtrip-$key.XXXXXX")
        # --no-dereference: several packages ship deliberately dangling
        # symlinks (var/run -> /run, var/lock -> /run/lock -- runtime
        # tmpfs mountpoints that don't exist in a static tree; systemd's
        # own usr/lib/environment.d/99-environment.conf -> ../../../etc/
        # environment, which nothing ships either) -- diffing default
        # (dereferencing) tries to stat() through them and reports a
        # false-positive "No such file or directory" on BOTH trees
        # equally, not a real reconstruction gap. --exclude: libgcc_s.so{,.1}
        # is the one file this project ships OUTSIDE the archive/merge
        # pipeline on purpose -- target_sysroot_cc (lib/package.sh) `cp`s
        # the cross-compiler's own copy straight into the target tree,
        # documented there as never going through any package's tarball.
        if diff -rq --no-dereference \
            --exclude=libgcc_s.so --exclude=libgcc_s.so.1 \
            "$INSTALL_DIR/$key" "$recon" > "$diff_log" 2>&1; then
            ok "install/$key reconstructs byte-identically from archive/$key (ORDER replay)"
        else
            not_ok "install/$key reconstructs byte-identically from archive/$key (ORDER replay)"
            sed 's/^/# /' "$diff_log" | head -20
        fi
        rm -f "$diff_log"
        rm -rf "$recon"
    done
fi

rm -rf "$RECON_ROOT"

if [ "$found" -eq 0 ]; then
    skip "roundtrip" "no archive/<key>/ORDER found"
fi

tap_summary
