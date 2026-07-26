# tests/tap.sh -- shared TAP-ish helpers, sourced (not executed) by every
# tests/*.sh. Kept deliberately tiny and POSIX/ash-clean (no `local`, no
# bashisms) since tests/syntax-ash.sh parses this file too.
#
# Contract for every test script that sources this:
#   . "$(dirname "$0")/tap.sh"
#   ... call ok/not_ok/skip as assertions run ...
#   tap_summary   # prints the summary line and exits 0/1
#
# `run` is the one non-obvious helper here -- see its own comment below for
# why a plain `if cmd; then ... fi` is NOT always safe for testing this
# project's framework code.

_tap_count=0
_tap_fail=0

# ok "<assertion name>"
ok() {
    _tap_count=$((_tap_count + 1))
    echo "ok - $1"
}

# not_ok "<assertion name>[: detail]"
not_ok() {
    _tap_count=$((_tap_count + 1))
    _tap_fail=$((_tap_fail + 1))
    echo "not ok - $1"
}

# skip "<assertion name>" "<reason>" -- counts as a pass (not a failure) so
# an incrementally-built tree (some SYSTEM_KEYs not built yet, some
# platforms absent) never turns the suite red for something that simply
# hasn't been built.
skip() {
    _tap_count=$((_tap_count + 1))
    echo "ok - $1 # SKIP $2"
}

# Print the final summary and exit 0 (all assertions passed) or 1 (at least
# one didn't). Every tests/*.sh ends with this, so it's runnable standalone
# (`sh tests/unit.sh`) as well as orchestrated by tests/run.sh.
tap_summary() {
    echo "1..$_tap_count"
    if [ "$_tap_fail" -eq 0 ]; then
        echo "# PASS ($_tap_count assertions)"
        exit 0
    else
        echo "# FAIL ($_tap_fail/$_tap_count assertions failed)"
        exit 1
    fi
}

# run CMD...  -- invoke CMD with errexit genuinely ACTIVE, and capture its
# exit status into $RUN_RC without aborting the calling script.
#
# Why not just `if cmd; then ok; else not_ok; fi`: per POSIX/bash errexit
# rules, a command used as the condition of `if` (or as a non-last element
# of `&&`/`||`) is exempted from -e -- and that exemption applies to the
# ENTIRE dynamic extent of a shell FUNCTION called there, i.e. every command
# INSIDE it too. That is exactly the shape of the regression this suite
# exists to catch (lib/package.sh's `_once` briefly became `$step && touch
# ...`, which hid a failure deep inside a package's build()/install()).
# Testing that behavior from inside another errexit-suppressing wrapper
# would hide the very failure being tested, in both the buggy and fixed
# cases. Running the command in a subshell that re-enables -e as its own
# first, unconditional statement -- itself invoked as a plain top-level
# statement, not an if/&&/|| operand -- keeps errexit exactly as "live" as
# it is for a real `./lfs` invocation.
run() {
    set +e
    ( set -e; "$@" )
    RUN_RC=$?
    set -e
}
