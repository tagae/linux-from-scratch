#!/bin/sh
# tests/run.sh -- orchestrates the whole `make check` regression suite:
#   Tier 0  tests/syntax.sh    -- host (delegates its ash half to a container)
#   Tier 1  tests/unit.sh      -- scratch container, framework mechanics
#   Tier 2  tests/artifacts.sh -- scratch container, built-tree/tarball checks
#   Tier 3  tests/roundtrip.sh -- scratch container, archive->install gold round trip
#
# Tier 4, the boot matrix (`./test` / `make test`), is separate and
# deliberately NOT run here -- it needs QEMU and a full image build, which
# is exactly what this suite exists to run instead of, for the failure
# classes it can catch (see tests/README.md). Runs every tier regardless of
# earlier failures, so one bad tier doesn't hide the others, then exits
# non-zero if any tier failed.
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$PROJECT_DIR"

overall_rc=0

run_tier() {
    name=$1
    shift
    echo
    echo "==> $name"
    if "$@"; then
        echo "==> $name: PASS"
    else
        echo "==> $name: FAIL"
        overall_rc=1
    fi
}

run_tier "tests/syntax.sh"    sh tests/syntax.sh
run_tier "tests/unit.sh"      docker compose run --rm scratch sh tests/unit.sh
run_tier "tests/artifacts.sh" docker compose run --rm scratch sh tests/artifacts.sh
run_tier "tests/roundtrip.sh" docker compose run --rm scratch sh tests/roundtrip.sh

echo
if [ "$overall_rc" -eq 0 ]; then
    echo "==> make check: ALL GREEN"
else
    echo "==> make check: FAILED (see tier output above)"
fi
exit "$overall_rc"
