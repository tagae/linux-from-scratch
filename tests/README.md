Regression tests
=================

Fast, deterministic, no-QEMU checks: `make check` (or `sh tests/run.sh`
directly). Seconds to low minutes, no package builds. This is Stage 1 of a
larger testing effort; Stage 2 (a functional in-guest probe layer, driven
from a booted system rather than static trees) is planned but not built --
nothing under `tests/` implements it.

Tiers
-----

* **Tier 0 -- `tests/syntax.sh`.** Parse-only. Two halves that each need a
  different place to run:
  - a Makefile parse check (`make -n check`) -- runs on the **host**, since
    neither the Makefile nor a real `make` exist inside either container
    (`docker-compose.yaml` bind-mounts `lfs`/`lib`/`package`/`tests`/... into
    them, never the Makefile itself);
  - every `lib/`, `package/`, `tests/` script and `lfs` itself, parsed with
    **real busybox ash** (`tests/syntax-ash.sh`, invoked from `syntax.sh`
    via `docker compose`) -- *not* `bash -n`. Every script here is
    `#!/bin/sh`, and on the busybox-init flavor (and the busybox guest)
    `/bin/sh` really is busybox ash; `bash -n` happily accepts bashisms ash
    rejects, which would give false confidence exactly where portability
    matters. Prefers this project's own statically-linked busybox (built by
    `package/busybox.sh` for every flavor) when an LFS build already
    exists; falls back to the bootstrap container's Debian-packaged
    `busybox` otherwise, so this tier never hard-requires a prior
    `make tools`/`make system`. The `test` harness itself is skipped here
    on purpose -- it's `#!/usr/bin/expect` (Tcl), not sh.

* **Tier 1 -- `tests/unit.sh`.** Framework mechanics: sources the real
  `lib/base.sh`/`lib/package.sh` and drives them directly (plus, for
  `_once`, through a throwaway fixture package under `tests/fixtures/`)
  rather than reimplementing their logic. Covers:
  - **`_once` aborts (non-zero exit, no stamp) when a step fails** -- the
    regression this whole suite exists to guard. `_once` briefly read
    `"$step && touch $stamp"`; because a failing command on the left of
    `&&` is exempted from `errexit` for its *entire* call tree, a failure
    deep inside a package's `build()`/`install()` was silently swallowed
    and the surrounding build carried on as if nothing had gone wrong.
  - `verify_hash` accepts a correct hash, rejects a wrong one, rejects a
    malformed one with no `algo:` prefix.
  - `_source` variable hygiene: derived `package_*` vars (name, version,
    source hash, ...) don't leak from one `_source`d package into the
    next, but the ambient scenario vars (`package_variant`,
    `package_install_dir`, `package_merge_dir`) deliberately do survive,
    since umbrellas rely on that to hand a scenario down to every member.
  - `unarchive FILE` with no DEST resolves under `$INSTALL_DIR/$SYSTEM_KEY`,
    never bare `/`.
  - `default_archive`'s ORDER dedup: re-archiving after only the tarball
    (not its ORDER line) was cleared doesn't grow a duplicate line.

  Runs inside the scratch container (`docker compose run --rm scratch sh
  tests/unit.sh`) -- it only needs `lib/base.sh`/`lib/package.sh` and a
  shell, both present unconditionally there, so it does not require
  anything to have been built yet (`tools`/`system`/`image`).

* **Tier 2 -- `tests/artifacts.sh`.** Assertions over whatever
  `archive/<key>/` and `install/<key>/` trees already exist (SKIPs, not
  fails, anything absent, so the suite stays useful incrementally):
  - every `*.tar.xz` is > 1 KB and `tar tf` lists > 0 entries (catches the
    empty-160-byte-tarball class a stale stamp can produce);
  - tarball contents are FHS-rooted (at least one of `usr`/`etc`/`bin`/
    `boot`/... at the top level -- see the note in the script about why
    this is "at least one", not "every entry", given a pre-existing,
    out-of-scope quirk in the perl package's own tarball);
  - `ORDER` exists and is consistent both ways with the tarballs actually
    on disk;
  - a couple of canary binaries (`usr/bin/busybox`, falling back to
    `usr/lib/libc.so.6`) have the right ELF machine type for the platform,
    read straight from the ELF header rather than trusting file naming;
  - if the gnupg family is installed for a given key, `usr/bin/gpg` links
    `libgcrypt` and `usr/libexec/scdaemon` links `libusb` (via
    `NEEDED`, using the target `tools/bin/<triple>-readelf`).

  Also runs inside the scratch container -- `install/` is a named Docker
  volume (invisible on the host), and the per-target `readelf` binaries
  live under `tools/`, also a named volume.

* **Tier 3 -- `./test` / `make test`.** The existing, slow, real
  boot-matrix harness (QEMU boot, log in, poweroff). Unchanged by this
  work and not run by `make check` -- it stays the ground truth for "does
  it actually boot", which Tiers 0-2 deliberately do not attempt to prove.

Running
-------

```
make check                         # everything, via tests/run.sh
sh tests/syntax.sh                 # Tier 0 alone (host)
docker compose run --rm scratch sh tests/unit.sh       # Tier 1 alone
docker compose run --rm scratch sh tests/artifacts.sh  # Tier 2 alone
```

Each script is independently runnable, prints TAP-ish `ok - <name>` /
`not ok - <name>` lines plus a trailing summary, and exits non-zero on any
failure -- `tests/run.sh` just runs all three and aggregates.

Fixtures live under `tests/fixtures/` (currently just `tests/fixtures/
package/`, pointed to by `PACKAGE_DIR` for the duration of the relevant
`tests/unit.sh` checks) and are never referenced from the real `package/`
directory or a real build.

Stage 2 (not built)
--------------------

A functional in-guest probe layer -- booting an image and asserting on
live system behavior (services up, a shell command's actual output, ...)
rather than static trees -- is the planned next stage. It is out of scope
here and nothing under `tests/` implements it; Tier 3 (`./test`) remains
the only thing in this repo that actually boots an image.
