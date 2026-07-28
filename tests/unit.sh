#!/bin/sh

# tests/unit.sh -- Tier 1: framework mechanics. Sources the REAL lib/base.sh
# and lib/package.sh and drives them directly (plus, for _once, through a
# throwaway fixture package under tests/fixtures/) rather than
# reimplementing their logic -- a passing test here means the actual
# production code behaves, not a model of it.
#
# Runs inside the scratch container, where lib/*.sh and a shell exist:
#   docker compose run --rm scratch sh tests/unit.sh
# It does not need anything ever built (tools/install/archive) -- only
# lib/base.sh, lib/package.sh and a POSIX shell, both bind-mounted into that
# container unconditionally.

set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$PROJECT_DIR/tests/tap.sh"

. "$PROJECT_DIR/lib/base.sh"
. "$PROJECT_DIR/lib/package.sh"

FIXTURES_DIR=$PROJECT_DIR/tests/fixtures/package

# ============================================================
# Invariant: _once aborts (non-zero exit, no stamp) when a step fails.
#
# THE regression this whole suite exists to catch. _once briefly read
# "$step && touch $stamp" -- and because a failing command that is the left
# operand of "&&" is exempted from errexit for its entire call tree (see
# tap.sh's `run` comment), a failure anywhere inside a package's build()/
# install() was silently swallowed: the stamp was correctly skipped, but
# the surrounding build (require -> _install -> a real `system build`)
# carried on as if nothing had gone wrong (this is exactly how
# package/9p-config.sh's `cat > etc/fstab` failing with ENOENT once shipped
# a system with no fstab at all, without the build ever reporting an
# error). Drive this through the real require()/_source()/_once() path with
# fixture-once.sh, a package whose build() step can be told to fail.
# ============================================================

FIXTURE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/lfs-unit-once.XXXXXX")
PACKAGE_DIR=$FIXTURES_DIR
WORK_DIR=$FIXTURE_ROOT/work
SOURCE_DIR=$FIXTURE_ROOT/source
DOWNLOAD_DIR=$FIXTURE_ROOT/download
ARCHIVE_DIR=$FIXTURE_ROOT/archive
INSTALL_DIR=$FIXTURE_ROOT/install
mkdir -p "$WORK_DIR" "$SOURCE_DIR" "$DOWNLOAD_DIR" "$ARCHIVE_DIR" "$INSTALL_DIR"
# package_merge_dir left unset: without it, _install's stage->archive->merge
# block never runs (see lib/package.sh), so this invariant only exercises
# fetch/prepare/build/install -- exactly what it needs.
unset package_variant package_install_dir package_merge_dir package_version 2>/dev/null || true

FIXTURE_VERSION=1.0
FIXTURE_MARKER=$FIXTURE_ROOT/marker
STAMP=$WORK_DIR/fixture-once-$FIXTURE_VERSION/build/fixture-once/.build-fixture-once
export PACKAGE_DIR WORK_DIR SOURCE_DIR DOWNLOAD_DIR ARCHIVE_DIR INSTALL_DIR FIXTURE_VERSION FIXTURE_MARKER

# 1. A failing step must abort the whole require() call and must not stamp.
FIXTURE_SHOULD_FAIL=yes
export FIXTURE_SHOULD_FAIL
run require fixture-once
if [ "$RUN_RC" -ne 0 ]; then
    ok "_once: require() exits non-zero when a package step fails"
else
    not_ok "_once: require() exits non-zero when a package step fails (got exit 0 -- the errexit-swallow regression)"
fi
if [ -f "$STAMP" ]; then
    not_ok "_once: no stamp file is left behind after a failed step"
else
    ok "_once: no stamp file is left behind after a failed step"
fi
if [ -f "$FIXTURE_MARKER.ran-to-end" ]; then
    not_ok "_once: the step aborts at the failure, not after (a later statement did not run)"
else
    ok "_once: the step aborts at the failure, not after (a later statement did not run)"
fi

# 2. Flip to success: require() must exit zero, stamp appears, step really ran.
FIXTURE_SHOULD_FAIL=no
export FIXTURE_SHOULD_FAIL
rm -f "$FIXTURE_MARKER"
run require fixture-once
if [ "$RUN_RC" -eq 0 ]; then
    ok "_once: require() exits zero once the step succeeds"
else
    not_ok "_once: require() exits zero once the step succeeds (got exit $RUN_RC)"
fi
if [ -f "$STAMP" ]; then
    ok "_once: stamp file is created once the step succeeds"
else
    not_ok "_once: stamp file is created once the step succeeds"
fi
if [ -f "$FIXTURE_MARKER" ]; then
    ok "_once: the step actually ran (side-effect marker present)"
else
    not_ok "_once: the step actually ran (side-effect marker present)"
fi

# 3. Re-run with the stamp already present: the step must be fast-pathed.
rm -f "$FIXTURE_MARKER"
run require fixture-once
if [ "$RUN_RC" -eq 0 ]; then
    ok "_once: a stamped re-run still exits zero"
else
    not_ok "_once: a stamped re-run still exits zero (got exit $RUN_RC)"
fi
if [ -f "$FIXTURE_MARKER" ]; then
    not_ok "_once: a stamped re-run fast-paths the step (marker was recreated -- step re-ran)"
else
    ok "_once: a stamped re-run fast-paths the step (not re-run)"
fi

rm -rf "$FIXTURE_ROOT"
unset FIXTURE_SHOULD_FAIL FIXTURE_MARKER FIXTURE_VERSION

# ============================================================
# Invariant: verify_hash (lib/base.sh) -- guards every download's integrity
# check (get()/patch_source()); a silently-accepted wrong or malformed hash
# would defeat the entire point of pinning package_source_hash.
# ============================================================

HASH_FILE=$(mktemp "${TMPDIR:-/tmp}/lfs-unit-hash.XXXXXX")
printf 'linux from scratch\n' > "$HASH_FILE"
GOOD_SHA=$(sha256sum "$HASH_FILE" | awk '{print $1}')
# Flip the leading hex digit so BAD_SHA is guaranteed to differ from
# GOOD_SHA, without depending on any external tool beyond sha256sum itself.
case $GOOD_SHA in
    a*) BAD_SHA="b${GOOD_SHA#?}" ;;
    *)  BAD_SHA="a${GOOD_SHA#?}" ;;
esac

run verify_hash "$HASH_FILE" "sha256:$GOOD_SHA"
if [ "$RUN_RC" -eq 0 ]; then
    ok "verify_hash accepts a correct hash"
else
    not_ok "verify_hash accepts a correct hash (got exit $RUN_RC)"
fi

run verify_hash "$HASH_FILE" "sha256:$BAD_SHA"
if [ "$RUN_RC" -ne 0 ]; then
    ok "verify_hash rejects a wrong hash"
else
    not_ok "verify_hash rejects a wrong hash (got exit 0 -- accepted a bad digest)"
fi

# Malformed: no "algo:" prefix at all (a bare digest is not "<digest>sum",
# it's not a command -- every pin must name its algorithm).
run verify_hash "$HASH_FILE" "$GOOD_SHA"
if [ "$RUN_RC" -ne 0 ]; then
    ok "verify_hash rejects a malformed hash with no algo: prefix"
else
    not_ok "verify_hash rejects a malformed hash with no algo: prefix (got exit 0)"
fi

rm -f "$HASH_FILE"

# ============================================================
# Invariant: _source var hygiene -- derived package_* vars (package_name,
# package_version, package_source_hash, ...) are cleared on every _source
# entry, so an umbrella's own values never leak into a member it require()s;
# but the ambient scenario vars (package_variant, package_install_dir,
# package_merge_dir) are deliberately NOT cleared, so umbrellas can hand a
# scenario down to every member just by presetting them once.
# ============================================================

WORK_DIR=$(mktemp -d "${TMPDIR:-/tmp}/lfs-unit-hygiene.XXXXXX")
PACKAGE_DIR=$FIXTURES_DIR
package_variant=probe-variant
package_install_dir=/probe/install
package_merge_dir=/probe/merge

_source fixture-a
name_a=$package_name
version_a=$package_version
hash_a=${package_source_hash:-<unset>}

_source fixture-b
name_b=$package_name
version_b=$package_version
hash_b=${package_source_hash:-<unset>}

if [ "$name_a" = fixture-a ] && [ "$name_b" = fixture-b ]; then
    ok "_source: package_name is re-derived per package (B doesn't inherit A's)"
else
    not_ok "_source: package_name is re-derived per package (got A=$name_a B=$name_b)"
fi
if [ "$version_a" = 1.0 ] && [ "$version_b" = 2.0 ]; then
    ok "_source: package_version is B's own, not inherited from A"
else
    not_ok "_source: package_version is B's own, not inherited from A (got A=$version_a B=$version_b)"
fi
if [ "$hash_b" = "<unset>" ]; then
    ok "_source: package_source_hash does not leak from A into B"
else
    not_ok "_source: package_source_hash does not leak from A into B (got '$hash_b')"
fi
if [ "$package_variant" = probe-variant ] && [ "$package_install_dir" = /probe/install ] && [ "$package_merge_dir" = /probe/merge ]; then
    ok "_source: ambient scenario vars (variant/install_dir/merge_dir) survive across packages"
else
    not_ok "_source: ambient scenario vars survive across packages (variant=$package_variant install_dir=$package_install_dir merge_dir=$package_merge_dir)"
fi

rm -rf "$WORK_DIR"
unset package_variant package_install_dir package_merge_dir

# ============================================================
# Invariant: unarchive DEST safety -- `unarchive FILE` with no DEST resolves
# to $INSTALL_DIR/$SYSTEM_KEY, NEVER bare "/" (the build containers
# bind-mount the toolchain read-only at /usr/{bin,lib}, so extracting a
# tarball straight onto "/" would be wrong at best).
# ============================================================

UNARCHIVE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/lfs-unit-unarchive.XXXXXX")
INSTALL_DIR=$UNARCHIVE_ROOT/install
SYSTEM_KEY=test-key
mkdir -p "$INSTALL_DIR"

if [ "$INSTALL_DIR/$SYSTEM_KEY" != / ]; then
    ok "unarchive: the default DEST it computes is not bare /"
else
    not_ok "unarchive: the default DEST it computes is not bare / (INSTALL_DIR/SYSTEM_KEY resolved to /)"
fi

STAGE_DIR=$UNARCHIVE_ROOT/stage/probe
mkdir -p "$STAGE_DIR"
: > "$STAGE_DIR/marker.txt"
FIXTURE_TAR=$UNARCHIVE_ROOT/fixture.tar
(cd "$UNARCHIVE_ROOT/stage" && tar -cf "$FIXTURE_TAR" probe)

run unarchive "$FIXTURE_TAR"
if [ "$RUN_RC" -eq 0 ] && [ -f "$INSTALL_DIR/$SYSTEM_KEY/probe/marker.txt" ]; then
    ok "unarchive: with no DEST, the tarball actually lands under \$INSTALL_DIR/\$SYSTEM_KEY"
else
    not_ok "unarchive: with no DEST, the tarball actually lands under \$INSTALL_DIR/\$SYSTEM_KEY (exit=$RUN_RC)"
fi

rm -rf "$UNARCHIVE_ROOT"
unset INSTALL_DIR SYSTEM_KEY

# ============================================================
# Invariant: default_archive's ORDER dedup -- ORDER records each tarball
# once, in merge order. Re-archiving after only the tarball itself was
# cleared (ORDER left intact -- exactly the gotcha this project's own
# packaging notes call out: clearing a tarball without also clearing its
# ORDER line) must not grow a second, duplicate ORDER line.
# ============================================================

ARCHIVE_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/lfs-unit-archive.XXXXXX")
ARCHIVE_DIR=$ARCHIVE_ROOT/archive
SYSTEM_KEY=test-key
package_install_dir=$ARCHIVE_ROOT/stage
mkdir -p "$package_install_dir"
: > "$package_install_dir/payload"
unset package_variant package_merge_dir

_source fixture-a
ORDER_FILE=$ARCHIVE_DIR/$SYSTEM_KEY/ORDER
TARBALL=$ARCHIVE_DIR/$SYSTEM_KEY/$package_archive

run default_archive
if [ "$RUN_RC" -eq 0 ] && [ -f "$TARBALL" ]; then
    ok "default_archive creates the tarball"
else
    not_ok "default_archive creates the tarball (exit=$RUN_RC)"
fi

# Simulate the gotcha: tarball cleared, ORDER left intact.
rm -f "$TARBALL"

run default_archive
if [ "$RUN_RC" -eq 0 ] && [ -f "$TARBALL" ]; then
    ok "default_archive re-creates a tarball that was cleared on its own"
else
    not_ok "default_archive re-creates a tarball that was cleared on its own (exit=$RUN_RC)"
fi

ORDER_COUNT=$(grep -cxF "$package_archive" "$ORDER_FILE" 2>/dev/null || true)
if [ "${ORDER_COUNT:-0}" -eq 1 ]; then
    ok "default_archive's ORDER dedup: re-archiving lists the tarball only once"
else
    not_ok "default_archive's ORDER dedup: re-archiving lists the tarball only once (found $ORDER_COUNT lines)"
fi

rm -rf "$ARCHIVE_ROOT"

# ============================================================
# Invariant: has_cap (lib/base.sh) -- exact-word membership in $CAPS.
# The one shared guard behind every capability conditional (lfs's qemu
# case, the bootable-* umbrellas' optional members), so its word-boundary
# semantics are load-bearing: "net" must NOT match inside "network", and
# an empty or unset CAPS must enable nothing.
# ============================================================

CAPS="9p network"
if has_cap network && has_cap 9p; then
    ok "has_cap: finds each enabled capability"
else
    not_ok "has_cap: finds each enabled capability"
fi

if has_cap net || has_cap work || has_cap usb; then
    not_ok "has_cap: no substring or absent-cap false positives"
else
    ok "has_cap: no substring or absent-cap false positives"
fi

CAPS=
if has_cap network; then
    not_ok "has_cap: empty CAPS enables nothing"
else
    ok "has_cap: empty CAPS enables nothing"
fi

unset CAPS
if has_cap network; then
    not_ok "has_cap: unset CAPS enables nothing"
else
    ok "has_cap: unset CAPS enables nothing"
fi

tap_summary
