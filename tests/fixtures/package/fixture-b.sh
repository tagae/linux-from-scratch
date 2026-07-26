# tests/fixtures/package/fixture-b.sh -- paired with fixture-a.sh for
# tests/unit.sh's _source variable-hygiene check. Never referenced from
# package/ or a real build. Deliberately leaves package_source_hash unset,
# so the test can confirm it does NOT inherit fixture-a.sh's value.
package_version=2.0
