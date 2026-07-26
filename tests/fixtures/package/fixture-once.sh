# tests/fixtures/package/fixture-once.sh -- throwaway package for
# tests/unit.sh, NEVER referenced from package/ or a real build. Drives the
# REAL require()/_source()/_once() path (lib/package.sh) with a single,
# controllable build() step, to exercise _once's errexit-on-failure
# behavior through actual production code rather than a reimplementation.
#
#   FIXTURE_SHOULD_FAIL=yes   build() fails (return 1)
#   FIXTURE_SHOULD_FAIL=no    build() succeeds (default)
#   FIXTURE_MARKER            (required) touched every time build() actually
#                             RUNS; still absent after a stamped re-run
#                             proves _once fast-pathed it instead of
#                             re-running the step.
#   FIXTURE_VERSION           (required) becomes package_version, so the
#                             caller can predict this fixture's stamp path.
package_version=${FIXTURE_VERSION:?FIXTURE_VERSION must be set}
package_source=none

build() {
    : > "${FIXTURE_MARKER:?FIXTURE_MARKER must be set}"
    # The failing command deliberately is NOT build()'s last statement --
    # that shape is the whole point. The real bug this guards was never
    # about a step's own *final* exit status; it was that "$step && touch"
    # disables errexit for $step's entire call tree, so a failure BEFORE a
    # function's last statement got silently stepped over and execution
    # "kept running past the failed command" (see lib/package.sh's own
    # comment on _once) all the way to a later, successful statement --
    # which then becomes the function's reported exit status. Reproduce
    # that shape here: if the failure below is swallowed, execution reaches
    # the marker after it and build() reports success despite having
    # failed midway.
    if [ "${FIXTURE_SHOULD_FAIL:-no}" = yes ]; then
        false
    fi
    : > "$FIXTURE_MARKER.ran-to-end"
}

install() {
    mkdir -p "$package_install_dir"
    : > "$package_install_dir/installed"
}
