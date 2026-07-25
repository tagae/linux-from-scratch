Package framework
=================

Every package is one script in `package/`, driven by `lib/package.sh`.
One framework serves every scenario; callers select behavior purely by
setting knobs.

Lifecycle
---------

`fetch → prepare → build → install [→ archive → merge]`, each step
stamped (`.step-<component>` in the package's build dir) so re-runs
fast-path. A package script overrides only the steps that differ from
the defaults. `depends()` (default no-op) runs first, unstamped.

* Stamps record *that* a step ran, not what it produced — clearing a
  work dir does not clear an already-written archive tarball; verify
  artifacts (`tar tf`, ELF headers), never just exit codes.
* errexit rule: never call a lifecycle function on the left of `&&`/`||`
  — that suppresses errexit for the function's entire body and
  silently swallows failures (bit this project once, badly).

Knobs
-----

Scripts declare defaults with `: ${var:=default}` and pass options with
`${var:+--flag=$var}`; a caller customizes by prefixing assignments:
`manpages=no require kmod`. Upstream defaults win unless a caller says
otherwise. Derived `package_*` vars are cleared on `_source` entry so
umbrella members don't inherit each other's; the ambient scenario vars
(`package_variant`, `package_install_dir`, `package_merge_dir`) are
deliberately NOT cleared — they carry the install scenario.

Scenarios
---------

* **Tools** (`lib/tools.sh`): imperative `install <pkg>` calls with
  `package_install_dir=$TOOL_DIR` preset — no staging, no archives.
* **Target** (`target_build_env`, applied for scratch-phase installs):
  `host=$target`, `prefix=/usr`, `package_variant=$SYSTEM_KEY`,
  `package_merge_dir=$INSTALL_DIR/$SYSTEM_KEY` — packages stage into
  per-package dirs and archive+merge (see packaging.md).
* **Guest** (`guest_build_env`, `LFS_PHASE=guest`): native build on the
  booted system, merging into the live `/` (see self-hosting.md).
* `-d DESTINATION` bypasses staging entirely (explicit install root).

`target_sysroot_cc` is the opt-in for packages that link libraries an
earlier package installed into the target tree: sets CC *and* CXX to
`$target-gcc/-g++ --sysroot=<merged tree>` (+ kernel-headers include,
`-L` for libtool's un-rebased relink). No-op unless `host=$target`.

Umbrellas and components
------------------------

A bootable system is a meta-package (`bootable-systemd`,
`bootable-busybox`): `package_meta=yes`, and `depends()` `require`s the
members in order with their knob prefixes — the whole system recipe in
one place, per init flavor. Optional features are plain packages
installed ad hoc (`./lfs install gnupg`), possibly with their own
`depends()` (ncdu → ncurses).

`name#component` selects a sub-component built from one source set
(`gcc#libstdc++`, `linux#headers`, `lvm2#device-mapper`,
`multipath-tools#kpartx`); unsupported components bail loudly.
