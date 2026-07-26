#!/bin/sh
# tests/syntax.sh -- Tier 0: fast, parse-only sanity checks. Two halves,
# each needing a different place to run:
#   - a Makefile parse check needs the real Makefile and a real `make`,
#     neither of which exist inside either container (docker-compose.yaml
#     bind-mounts only lfs/lib/package/tests/download/... into them, never
#     the Makefile itself) -- so this half runs on the host;
#   - every lib/package/tests/lfs script parsed with real busybox ash, not
#     `bash -n` (see tests/syntax-ash.sh for why) -- there's no ash on the
#     host, so that half is delegated to a container.
#
# Run directly: `sh tests/syntax.sh` (it shells out to docker compose
# itself for the ash half; nothing else here needs a container).
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$PROJECT_DIR/tests/tap.sh"

if command -v make > /dev/null 2>&1; then
    if out=$(cd "$PROJECT_DIR" && make -n check 2>&1 > /dev/null); then
        ok "make -n check parses cleanly"
    else
        not_ok "make -n check parses cleanly: $out"
    fi
else
    skip "make -n check parses cleanly" "make not found on PATH"
fi

if command -v docker > /dev/null 2>&1; then
    # Prefer the scratch container (tests this project's OWN built busybox
    # -- see tests/syntax-ash.sh); fall back to the bootstrap container's
    # Debian-packaged busybox when no LFS build exists yet (exit code 2 is
    # syntax-ash.sh's signal for "no ash here", distinct from 1 = "found
    # ash, found a real syntax error"), so this tier never hard-requires a
    # prior `make tools`/`make system`.
    set +e
    ash_out=$(cd "$PROJECT_DIR" && docker compose run --rm scratch sh tests/syntax-ash.sh 2>&1)
    ash_rc=$?
    set -e
    if [ "$ash_rc" -eq 2 ]; then
        echo "# no busybox in the scratch container/install volume yet -- retrying via the bootstrap container's Debian busybox"
        set +e
        ash_out=$(cd "$PROJECT_DIR" && docker compose run --rm bootstrap sh tests/syntax-ash.sh 2>&1)
        ash_rc=$?
        set -e
    fi
    printf '%s\n' "$ash_out"
    if [ "$ash_rc" -eq 0 ]; then
        ok "ash -n: every lib/package/tests script and lfs parse cleanly"
    else
        not_ok "ash -n: every lib/package/tests script and lfs parse cleanly (see output above)"
    fi
else
    skip "ash -n script checks" "docker not found on PATH"
fi

tap_summary
