# tests/fixtures/package/fixture-a.sh -- throwaway package for
# tests/unit.sh's _source variable-hygiene check, paired with fixture-b.sh.
# Never referenced from package/ or a real build. Sets package_source_hash
# deliberately (fixture-b.sh does not) so the test can confirm _source
# clears it between packages rather than leaking A's value into B.
package_version=1.0
package_source_hash=sha256:0000000000000000000000000000000000000000000000000000000000000
