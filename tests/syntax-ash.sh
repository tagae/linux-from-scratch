#!/bin/sh
# tests/syntax-ash.sh -- ash half of Tier 0, invoked BY tests/syntax.sh
# inside a container (never call this directly on the host -- there's no
# ash there). Parses every lib/package/tests script and `lfs` itself with
# REAL busybox ash, not `bash -n`.
#
# WHY ash, not bash -n: every one of these scripts is #!/bin/sh, and on the
# busybox-init flavor (and the busybox guest) /bin/sh really IS busybox ash
# -- the strictest real target this project ships to. `bash -n` happily
# accepts bashisms ash rejects, which would give false confidence exactly
# where portability matters.
#
# Exit codes: 0 = all parsed clean, 1 = at least one parse failure,
# 2 = no ash binary could be found at all (distinct from 1 so
# tests/syntax.sh knows to retry via the other container instead of
# reporting a bogus syntax failure).
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$PROJECT_DIR/tests/tap.sh"

# Prefer this project's OWN static busybox: package/busybox.sh forces
# CONFIG_STATIC=y unconditionally for every flavor, so it has no libc
# dependency and runs directly in whichever container we're in regardless
# of that container's own toolchain -- and it's the actual shipped ash, not
# a stand-in for it. Only reach for a busybox already on PATH (the
# bootstrap container's Debian-packaged one, once installed) when no LFS
# build exists yet, so this tier never hard-requires one.
BB=
for c in \
    "$PROJECT_DIR/install/virt/usr/bin/busybox" \
    "$PROJECT_DIR/install/busybox-virt/usr/bin/busybox" \
    "$PROJECT_DIR"/install/*/usr/bin/busybox \
    ; do
    if [ -x "$c" ]; then
        BB=$c
        break
    fi
done
if [ -z "$BB" ] && command -v busybox > /dev/null 2>&1; then
    BB=$(command -v busybox)
fi
if [ -z "$BB" ]; then
    echo "no busybox binary found (no LFS build yet, and no busybox on PATH)" >&2
    exit 2
fi
echo "# using ash from: $BB"

# lfs is the extensionless entry point; everything else is *.sh under lib/,
# package/ and tests/ (tests/ included, so a broken test script -- or
# fixture -- fails loudly here too). The `test` harness is deliberately
# excluded: it's #!/usr/bin/expect (Tcl), not sh, so ash -n on it would
# always fail regardless of its own correctness.
files=$( (cd "$PROJECT_DIR" && find lib package tests -name '*.sh' -type f | sort; printf '%s\n' lfs) )

for f in $files; do
    if err=$("$BB" ash -n "$PROJECT_DIR/$f" 2>&1); then
        ok "ash -n $f"
    else
        not_ok "ash -n $f: $err"
    fi
done

tap_summary
