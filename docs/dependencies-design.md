# Build dependencies: design proposal

**Question:** how can a recipe declare what it compiles against, and the framework enforce it, as
Yocto and Buildroot do, without losing what the framework does today?

**Answer:** give each recipe a `package_dependencies` list, and compile each package in a sysroot
that holds the declared dependencies and a fixed base set, nothing else. The sysroot keeps its one
path and is emptied and filled again before each package is built, so the compiler, pkg-config,
meson and every file that records the sysroot's path keep working unchanged. A missing dependency is
then a build error, not a matter of install order.

Status: proposal, not implemented. The first slice (steps 0 to 2 below) is about 40 lines of
framework code and one line per recipe.

## Today

- `lfs_system_build` makes two trees and empties both at the start (`lib/system.sh`):
  `system_dir` (`$INSTALL_DIR/$PROFILE`, which the image is made from) and one `sysroot`
  (`$WORK_DIR/$package_key/sysroot`), which holds the system's packages plus the kernel headers and
  every `dev` component. The cross gcc is configured with that sysroot (`--with-sysroot`), and
  pkg-config (`PKG_CONFIG_SYSROOT_DIR`, `PKG_CONFIG_LIBDIR`), the meson cross file (`sys_root`) and
  several `*-config` overrides name it too.
- `lfs_install_package X[#component]` builds the archive when it is missing and unpacks it into
  `$package_install_dir`, which the system build sets to the sysroot. `lfs_system_install X` also
  unpacks it into `system_dir`.
- The sysroot is cumulative: a recipe sees every package installed before it. Dependencies are the
  install order of the toolchain (`lib/system.sh`) and of the profile, kept by hand. The only declared dependency,
  `package_fetch_dependencies`, is about sources built in-tree (gcc's gmp, mpfr and mpc).
- A missing dependency builds whenever the order happens to be right, and `configure` picks up
  whatever the sysroot happens to hold. Options at the call sites (`sqlite=no`) exist to keep that
  result fixed.
- An archive is reused when it and its digest exist. Its key is the profile's name, so a changed
  dependency rebuilds nothing (`invalidate`: "The packages built
  against one that changed are not dropped with it").
- 18 products have an `lfs_install_package X#dev` line, 20 lines in all, in `lib/system.sh` (glibc)
  and the profiles.

## Requirements and non-goals

1. A recipe declares the target products it compiles against.
2. A package is compiled in a sysroot that holds a fixed base set (`system-files`,
   `linux#headers`, `glibc` and its `dev`, `gcc#runtime`) plus the transitive closure of its
   declared dependencies, each with its `dev` component. Nothing else installed earlier is visible.
3. A dependency that the build has not installed yet, or installs after its dependent, is an error
   that names both. An undeclared dependency is not in the sysroot, so its `configure` test or its
   link fails.
4. Kept: `dev` files never reach `system_dir`; `lfs_system_install` stays the record of what goes
   into the system (the SBOM's input); POSIX shell, no new tools; profile lists stay flat and
   ordered, with options at the call site.
5. A build that changes nothing stays free: no population when every archive exists.

Not in the first slice: isolating `TOOL_DIR` (build-machine tools stay shared), parallel package
builds (the build is serial), rebuilding dependents when a dependency changes, deriving the build
order or building dependencies automatically, runtime dependencies.

## What other projects do

| | Declared build deps | Sysroot of a build | Dev split | Dependents rebuilt when a dependency changes |
|---|---|---|---|---|
| Yocto / OpenEmbedded | `DEPENDS`; `RDEPENDS` for runtime | `recipe-sysroot` and `recipe-sysroot-native` per recipe, filled by hard links from the dependencies' staged output; the compiler gets `--sysroot` | `FILES:${PN}-dev` globs, `-staticdev`; images take `-dev` packages only on request | yes: the sstate signature includes the dependencies' hashes; hash equivalence stops a cascade whose output is unchanged |
| Buildroot | `<PKG>_DEPENDENCIES` (`host-foo` for tools) | with `BR2_PER_PACKAGE_DIRECTORIES`, `per-package/<pkg>/{host,target}` filled by rsync with hard links from the dependencies'; the toolchain wrapper passes `--sysroot` | none: staging has everything, `target-finalize` strips `target` | no (a full rebuild is advised) |
| Nix | `buildInputs`, `nativeBuildInputs` | only the inputs' store paths are visible | outputs (`out`, `dev`, ...); `buildInputs` take `dev` | yes, by input-addressed paths |
| Alpine, Debian | `makedepends`, `Build-Depends` | a chroot holding the build dependencies | `-dev` subpackages / packages | by hand |
| This repo | none (install order) | one cumulative sysroot | `move_to_dev_component` | no |

Taken from them:
- Buildroot and Yocto: a sysroot filled from the declared dependencies only, from artifacts that
  are already built (here, the archives play the part of sstate and the per-package directories).
- Yocto: the transitive closure (`.pc` `Requires` and `.la` `dependency_libs` need it), implicit
  base dependencies, and later a signature that includes the dependencies' signatures.
- Nix and Alpine: a dependency names the package and the framework adds its `dev` component.
- Gentoo and Debian: a separate class for build-machine tools (`BDEPEND`, `:native`), declared but
  not enforced at first.

Rejected:
- A per-package sysroot path with `--sysroot` at each compiler invocation (Yocto, Buildroot): the
  tools record the paths, so both projects rewrite `.la`, `.pc`, `.cmake` files and the like
  after staging (Buildroot's `PPD_FIXUP_PATHS`).
- Buildroot's per-package host directory: it copies the whole tool tree per package.
- Kconfig-style global options and automatic building of dependencies: options live at the call
  sites here, so the framework cannot build a dependency with the right ones.

## Design

### Declaring dependencies

Two new recipe variables, in the internal API and read-only like `package_fetch_dependencies`:

- `package_dependencies`: target products the package compiles against. A bare name stands for the
  product and its `dev` component when it has one; `linux#headers` names a component alone.
- `package_tool_dependencies`: build-machine packages (`swig`, `rust`, `python/cffi`). Recorded for
  the graph and the SBOM, checked at step 5.

`package_fetch_dependencies` stays: it fetches sources, a different thing.

The recipe is sourced in the caller's subshell, which already holds the call-site options, so a
declaration is plain shell that can read them:

```sh
# package/libgcrypt.sh
package_dependencies=libgpg-error

# package/libusb.sh
case ${udev:-yes} in yes) package_dependencies=systemd ;; esac

# package/gnupg.sh
package_dependencies="libgpg-error libassuan libgcrypt libksba npth"
case ${ccid_driver:-no} in yes) package_dependencies="$package_dependencies libusb" ;; esac
```

### Options at the call sites

The option variable that a recipe turns into a `configure` flag also decides the dependency:

- `X=no`: no dependency is declared, so the library is not in the sysroot, and the flag turns the
  feature off explicitly. Two safeguards for one statement. Explicit `=no` also covers a library
  that is in the sysroot only through the closure.
- `X=yes`: the dependency is declared and the flag makes `configure` fail without it. A missing
  package is reported by the framework first, by name.
- Unset: the recipe's `${X:-default}` follows upstream's default. A dependency is declared when
  upstream enables the feature by default, so that an unset option is not a silent autodetect.

A dependency's own options travel with it. `( udev=no; lfs_system_install libusb )` registers libusb
without `systemd`; gnupg's closure is computed from the registry, so it does not pull `systemd` back
in through libusb. Re-sourcing libusb's recipe under gnupg's options would.

Options that disable a library no recipe provides (`sqlite=no` with no SQLite recipe) are left out:
they would only restate the sysroot's content.

### The registry

`lfs_system_build` already rewrites a list of the system's packages (the SBOM design's step 1,
`$WORK_DIR/$PROFILE/packages`). It becomes the registry. `lfs_install_package` and
`lfs_system_install` append one line per product:

```
<product> <archive path relative to ARCHIVE_DIR> <system|build> <resolved dependencies...>
```

- A file, not a variable: a profile runs in a subshell.
- The resolved dependencies are those of the product as installed, with its own options.
- Archive paths, not names: dependencies can sit under other keys (the build tools under `tools`).
- A product installed twice resolves to its last line, as the last unpack wins today.
- `system` lines are what the image contains (the SBOM's `CONTAINS`); `build` lines are not
  shipped.

### The sysroot of a package

A new `lfs_prepare_sysroot` (in `lib/system.sh`), called by `lfs_archive_package` after `fetch` and
before `prepare`, only when the registry variable is set (the system build sets it; the tools
phases do not, and their `sysroot=$TOOL_DIR` must never be emptied):

1. empty `$sysroot`;
2. compute the closure of `sysroot_base` and `package_dependencies` from the registry, failing on a
   dependency that is not registered;
3. check each archive against its digest, and unpack them in registry order, so later files win;
4. the unpack is the body of `default_unarchive`, factored into one function.

It runs only when a package is actually built, so a build that changes nothing pays nothing.
`sysroot_base` is `system-files` before the toolchain and `system-files linux#headers glibc
gcc#runtime` after it: what today's cumulative sysroot holds at those points, which lets step 2 be
proved.

After a failure, `work/<key>/sysroot` holds exactly what the failed package saw.

Cost: `work` is a volume on the Linux VM's own file system, so the unpack writes at native speed;
hard links work there, reflinks do not. `archive/` is a bind mount of the host's directory
(`docker-compose.yaml`), so the archives are read through Colima's share. Nothing is measured; the
guess is 1 to 2 seconds for the base set per build, a few more for packages that need Python. A
later optimisation (Yocto's `sysroots-components`): unpack each archive once into `work` and
`cp -al` it into the sysroot; it needs care, since a build writing a sysroot file in place would
corrupt the cache.

### Why one path

| Option | Verdict |
|---|---|
| **A. One path, emptied and filled again per package** | gcc, pkg-config, the meson cross file, cmake, `gpgrt-config` overrides and every recorded path stay valid. Strictly serial builds, which they already are. |
| B. A directory per package and `--sysroot` at invocation | Needs an override in autotools, meson, cmake, the cargo wrapper and Python's recorded `CC`, and rewriting of recorded paths; archives of equal inputs would differ by build path. Gains parallel builds, which are not wanted. |
| C. A stable path that is a symlink to a per-package directory | Tools that resolve the link (cmake, meson, Python) record the per-package path. Saves nothing. |
| D. Mount namespace, overlay or bind mount | Needs privileges the scratch container lacks. |

Recommended: A. Its limit: the closure over-approximates, so direct use of an undeclared
*transitive* dependency is not caught. The check at step 5 (`DT_NEEDED` against the declared
dependencies) closes most of that. Yocto has the same gap.

### Profile lists

- `lfs_install_package X` builds and registers `X#dev` by itself when X's install set one aside, so
  the 20 `lfs_install_package X#dev` lines go (step 4). `lfs_system_install X` goes into the
  system; `lfs_install_package X` is build-only.
- The order is checked, not derived: `libgcrypt: needs libgpg-error, which this build installs
  after it, or not at all`. Deriving it would need the framework to build dependencies, with options
  that only the call sites know.
- `lfs system graph` can print the declared graph as dot.

## Cache and rebuilds

Steps 0 to 5 keep the archive keys. Enforcement applies to packages that are built, so the first
cold build is where hidden dependencies show up. Editing a recipe's `package_dependencies` is a
recipe edit: `invalidate` rule 2 drops its archive, and, as today, not its dependents.

Step 6, separate and later: a signature, as sstate has, replaces the profile's name as the archive
key. It is the SHA-256 of the recipe, its files directory and category helper, the values
of the options the recipe names, `target_*`, the flags, the component and the signatures of the
resolved dependencies from the registry. A changed dependency then rebuilds its dependents, and
systems with equal inputs share archives. It needs an archive prune command, reproducible archives
(`tar --sort=name`, `SOURCE_DATE_EPOCH`) to stop cascades of unchanged output, and it changes the
stale-state rules of `invalidate`. It deserves its own
design.

## Migration

Each step is verified alone (the build-iteration skill: `env-trace`, archive manifests, a no-op
build, QEMU).

| Step | Change | Proof |
|---|---|---|
| 0 | The registry, written by `lfs_install_package` and `lfs_system_install` (the SBOM's step 1) | `env-trace` identical; a no-op build compiles nothing; same image |
| 1 | `package_dependencies` in each target recipe, check-only: warn on a missing or late dependency | no archive changes; the warning list is empty. Draft the lists from the archives' `NEEDED`, `.pc` `Requires`, and the `found` lines of `config.log` and `meson-log.txt` |
| 2 | `lfs_prepare_sysroot`; the checks fail the build | archives away, cold build on pi0 **and** virt (the same-triple trap), manifest diff of every archive against the old ones; each difference is a hidden dependency, to declare or to accept; then the QEMU checks |
| 3 | Stop unpacking build-only archives into the sysroot during system builds; update the comments in `lib/system.sh` and CONTRIBUTING.md | `env-trace`; no-op image identical; no-op builds faster |
| 4 | Derived `dev`: delete the 20 `#dev` lines | registry identical before and after; nothing rebuilt |
| 5 | `package_tool_dependencies` checked against the tools installed; `DT_NEEDED` check of each built archive against its declared closure; optional `package_runtime_dependencies` for what `NEEDED` cannot see (Python imports); `lfs system graph` | new checks pass on the current tree |
| 6 | Signatures (above) | archive paths change once; the next build is a no-op |

The minimal first slice is steps 0 to 2: no change to the profiles, the keys, the toolchain,
`lib/meson.sh` or the pkg-config environment.

Expected hidden dependencies of step 2 (predictions from reading the recipes, not confirmed):
gnupg (zlib), libfido2 (zlib, libudev from systemd), pcsc-lite (systemd), ccid (pcsc-lite,
libusb), procps-ng and util-linux (ncurses), shadow and systemd (libxcrypt), systemd (util-linux's
libmount and libblkid, kmod), the target Python (zlib, libffi, openssl, ncurses, libuuid,
libxcrypt), `python/cffi`, `python/cryptography` and `python/pyscard` (python; cryptography also
openssl), mandoc (zlib). A comment describes the order-dependence that declared dependencies
remove: `package/bash.sh` (the termcap library "would then depend on what was installed before it").
Step 3 reconsiders it, and its pinned `bash_cv_termcap_lib`. The profiles already install the
libraries that several packages link, zlib among them.

## SBOM

The registry is the SBOM's list of packages, so one change serves both. `system` lines are what the
image `CONTAINS`; `build` lines and `dev` archives are SPDX packages that are not contained. The
declared graph gives the relationships: `BUILD_DEPENDENCY_OF` from `package_dependencies`,
`BUILD_TOOL_OF` from `package_tool_dependencies` and the cross toolchain, `DEPENDS_ON` and
`RUNTIME_DEPENDENCY_OF` from runtime dependencies and `NEEDED`. With enforcement, "built against"
is exact, and a `<archive>.deps` file next to each archive makes it a provenance record.

## Risks and open questions

- Finding the hidden dependencies takes cold builds of over 30 minutes each, on two platforms.
  Drafting the lists from `NEEDED` and the configure logs (step 1) cuts the rounds.
- Transitive closure hides direct use of transitive dependencies (see above).
- `TOOL_DIR` stays shared and cumulative: build-machine files are kept out by the existing rules,
  not by enforcement.
- Population cost for Python-heavy systems is not measured.
- Detecting that a package has a `dev` component (step 4) needs the work directory or the `dev`
  archive.
- Noticed on the way: `package/mpfr.sh` and `package/mpc.sh` pass
  `--with-sysroot=$INSTALL_DIR/$PROFILE`. They are built in-tree by gcc, so this is probably
  dead.
- Should `gcc#runtime` stay in the base set? The compiler finds libgcc in its own directory; kept
  for parity at first.
- Should the default `dev` globs gain `usr/lib/cmake` and `usr/share/cmake`, as Yocto's do?
  `libcbor` passes `usr/lib/cmake` by hand.
- Should runtime dependencies be declared, or only derived from `NEEDED` (plus Python imports)?

## Decisions for the owner

Each with the recommendation; none is made yet.

1. **A stable sysroot path, emptied and filled per package (A), or per-package directories with
   `--sysroot` (B).** A: every recorded path stays valid and nothing is rewritten.
2. **`package_dependencies` (and later `package_tool_dependencies`, `package_runtime_dependencies`)
   separate from `package_fetch_dependencies`.** Yes: sources and sysroot content differ.
3. **A bare dependency name implies its `dev` component, and the `#dev` lines go.** Yes: one line
   per package; `dev` still never reaches `system_dir`.
4. **Install order checked, not derived; no automatic building of dependencies.** Checked: the
   options live at the call sites.
5. **Transitive closure, not direct dependencies only.** Transitive: `.pc` and `.la` files need it.
6. **The registry shared with the SBOM.** Yes: one record for enforcement and SBOM.
7. **What an unset option means** (see Options at the call sites): declare a dependency when
   upstream enables the feature by default. The recipes then state upstream's defaults.
8. **A `PACKAGECONFIG`-style table** (`package_options="sqlite:sqlite ldap:openldap"`) from which
   the framework derives both flag and dependency. Not at first: start with the plain `case`, and
   add the table if the repetition hurts. It would replace every `${x:+--enable-x=$x}` line.
9. **Signature-based archive keys (step 6) replacing the key suffixes.** Later, as its own design.
10. **A hard-link unpack cache.** Only after measuring plain `tar`.

## Sources

Prior art, as found while researching; the documentation hosts `docs.yoctoproject.org` and
`git.openembedded.org` could not be reached, so Yocto details rest on these posts and pages and on
memory, and should be checked before relying on them.

- Yocto: https://docs.yoctoproject.org/ref-manual/structure.html (recipe-sysroot, sysroots-components),
  https://www.openembedded.org/pipermail/openembedded-architecture/2016-November/000336.html and
  `.../000342.html` (recipe-specific sysroots), https://docs.yoctoproject.org/3.3/ref-manual/migration-2.3.html,
  https://docs.yoctoproject.org/4.0/overview-manual/concepts.html (signatures, hash equivalence),
  https://docs.yoctoproject.org/3.3/ref-manual/qa-checks.html (`build-deps`),
  https://www.kc8apf.net/2018/10/conflicted-about-sysroots/ (transitive dependencies)
- Buildroot: https://buildroot.org/downloads/manual/manual.html and
  https://github.com/buildroot/buildroot/blob/master/docs/manual/common-usage.adoc (per-package
  directories), https://lore.kernel.org/all/20210624202010.GA2852@scaer/ and
  https://lists.buildroot.org/pipermail/buildroot/2021-June/678111.html (rsync with hard links, path
  fixups), https://buildroot.org/downloads/manual/rebuilding-packages.txt
- Gentoo `BDEPEND`: https://dev.gentoo.org/~mgorny/articles/the-ultimate-guide-to-eapi-7.html
- Nix: https://ekala-project.github.io/nix-book/ch06-09-multiple-outputs.html and
  https://ekala-project.github.io/nix-book/ch06-04-build-dependencies.html
- Alpine `makedepends` and Debian `:native` rows are from memory.
