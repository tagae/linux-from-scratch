Simplification Review
=====================

A review of the whole tree of `main` as of 2026-11-26, with a view to simplifying it. Nothing but this
file was changed, and nothing was built. Each claim below was checked against the code (grep for
every use before calling something dead); what was not checked says so.


Summary
-------

Most of the code is lean and earns what it does. Three things stand out:

* **The recipes repeat one dispatch about 140 times.** 46 recipes wrap each hook in
  `case $package_component in <name>) ... ;; dev) install_component ;; *) default_X ;; esac`. That
  scaffolding is about 930 lines of the roughly 4,000 lines of recipes, and the only other
  components with real work are `linux#headers` and `gcc#runtime`. If the framework dispatches
  components, the recipes become their bodies (P1).
* **Dead code and dead knobs.** Three recipes whose build is never run (gmp, mpfr, mpc), three
  components nothing installs, a kernel branch no platform takes, a helper nothing calls, a QEMU
  variable that always equals its default, an image shortcut that a `make` flow can never reach,
  and about 40 recipe options that no profile or phase sets (P2, P3, P4).
* **Facts that are stated several times and have already drifted.** The list of `LFS_*` variables
  is in `lfs` and in `docker-compose.yaml`, and Compose lacks `LFS_MACHINE`. The list of profiles is
  in four places in CI and lint. Five `LFS_*` variables end up in archives that `bin/invalidate`
  never drops for them (B1, B2, P7, P9).

Five real bugs, all small, are listed in their own section.

Almost every recipe-side proposal makes archives stale, and P1 alone makes every one stale. The
cheapest path that gives up nothing is to land the recipe and framework proposals (P1, P2, P3, P5,
P6, P9, P10, P12, P13, P15, P16) as one batch, so that they cost **one** full rebuild, and to verify
the batch with archive manifests (see "Verifying the batch"). The CI, Compose, test and skill
proposals stand alone and make nothing stale.

| Id  | Area                                         | Lines saved | Risk    | Owner decides         | Archives made stale                       |
|-----|----------------------------------------------|-------------|---------|-----------------------|-------------------------------------------|
| P1  | Framework dispatches components              | ~900        | Medium  | Yes (framework, rule) | Every archive (lib/package.sh, rule 8)    |
| P2  | Dead code and branches                       | ~110        | Low     | Yes (framework parts) | Every archive (lib/, platform/)           |
| P3  | Recipe options that nothing sets             | ~45         | Low     | Yes (recipe options)  | The 17 recipes concerned                  |
| P4  | Image up-to-date shortcut never fires        | ~12         | Low     | Yes (framework)       | None                                      |
| P5  | `meson_prepare` wipes and writes cross file  | ~20         | Low     | Yes (framework)       | The 7 meson recipes                       |
| P6  | CMake cross settings in one helper           | ~10         | Low     | Yes (framework)       | Every archive (new lib file), or 2        |
| P7  | CI: one matrix instead of three workflows    | ~85         | Low     | Trade-off (names)     | None                                      |
| P8  | Compose and Dockerfile lists stated once     | ~65         | Low/Med | Yes (framework)       | With `--docker`: every archive            |
| P9  | Per-build variables kept out of archives     | ~15         | Low     | Yes (interface)       | system-files, linux                       |
| P10 | `man`/`info` set by the profile              | ~0          | Low     | Yes (where policy is) | Every pi0-pgp archive                     |
| P11 | Test helpers for repeated idioms             | ~20         | Low     | No                    | None                                      |
| P12 | systemd's sysctl file shipped as a file      | ~0          | Low     | No                    | systemd                                   |
| P13 | Fragments no profile names; a doubled option | ~60         | Low     | Yes (catalogue)       | busybox, linux                            |
| P14 | `image.sh` layout branches                   | ~10         | Low     | Yes (framework)       | None                                      |
| P15 | The root's kernel arguments in one place     | ~3          | Low     | Yes (framework)       | boot, every virt archive                  |
| P16 | Static accounts of unbuilt daemons           | ~18         | Low/Med | No                    | systemd                                   |
| P17 | One expect harness for the QEMU skill        | ~35         | Low     | No                    | None                                      |
| P18 | Small leftovers (lint loops, `.PHONY`, ...)  | ~20         | Low     | Partly                | None                                      |

The total is about **1,400 lines** out of the roughly 11,000 that are not patches or prose.


Coverage
--------

`git ls-files` lists 326 files. I read these in full: `lfs`; every file of `lib/`, `bin/`, `check/`
and `platform/`; all 101 recipes (`package/*.sh`, `package/python/*.sh`); the files that recipes
ship (`package/*/etc`, `package/*/usr`); the three profiles, all their installed files and all 46
tests; `Makefile`, the three Dockerfiles, `docker-compose.yaml`, `.dockerignore`, `.gitignore`;
the nine workflows; the skill scripts, `boot.tcl` and the examples; `tcllsrc.tcl` and `.tcl-ls/`.

Read less closely:

* The kernel and BusyBox `.config` fragments: I checked which ones profiles use and which options
  are set in more than one fragment, but did not review each option.
* The patches (glibc, Python, wget, make-ca, the Pi's device tree): I checked only how they are
  applied.
* Prose (`README.md`, `CONTRIBUTING.md`, `docs/`, `profile/*.md`, the man page, the `SKILL.md`
  files): read for the facts it states about the code, and left to the agent that trims prose.

The proposals respect CONTRIBUTING.md: upstream units and tools stay as shipped, no patch is
added, and no proposal trades quality for build time.


Real Bugs
---------

**B1. Compose drops `LFS_MACHINE`.** `lfs:59` passes `LFS_MACHINE` to builds, and
`package/linux.sh:66` makes it the kernel's default host name. The `scratch` service's
`environment` list (`docker-compose.yaml:48-59`) does not include it, so
`make docker-image LFS_MACHINE=x` drops it without a word. P9 removes the variable; otherwise, add
it to the list.

**B2. Some variables reach archives that `bin/invalidate` never drops for them.** `LFS_MACHINE`
ends up in the kernel's `.config` (`linux.sh:66`). `LFS_VERSION_CODENAME`, `LFS_RELEASE_TYPE`,
`LFS_DISTRIB_CODENAME` and `LFS_DISTRIB_DESCRIPTION` end up in `etc/os-release` and
`etc/lsb-release` inside the system-files archive (`package/system-files.sh:30-42`). Invalidation
goes by paths (`bin/invalidate:20-49`), so if one of these changes, the old archive is reused and the
image silently carries the old value. `LFS_RELEASE` avoids this by being written at the image step
(`lib/image.sh:212-220`). P9 fixes it.

**B3. `bin/version` always adds `r` to the hash.** `bin/version:70` prints `1.0.0-r<hash>`.
`CONTRIBUTING.md:210-212` and the script's own header (`bin/version:5-7`) say that only a hash
made of digits alone with a leading 0 takes the `r` (`0.2.0-abc1234`). The code is the simpler,
uniform rule and is valid SemVer: I recommend fixing the two texts. The header's "When not in the `main` branch"
is also wrong: what matters is whether the tree is on the tag's commit.

**B4. `get` unpacks dash and the Pi firmware again on every fetch.** `lib/base.sh:56-63` decides
whether a tarball is already unpacked by its name less `.tar.*`. Two tarballs unpack under another
name: `dash_0.5.13.5.orig.tar.gz` holds `dash-0.5.13.5/`, and `raspi-firmware_1.20260521.orig.tar.xz`
holds `raspi-firmware-1.20260521/` (checked with `tar tf`). Each build of those packages therefore
extracts again over the existing tree. That is harmless today because neither package has a patch.
If one gets a patch, the extraction restores the unpatched files while the `.patched-*` stamp stays,
so `apply_patch` skips the patch and the package builds from unpatched source. The fix is a stamp
per tarball, as `apply_patch` has: `[ -f $source_dir/$dir/.unpacked-$archive ] || { unpack ...;
touch ...; }`. That is a lib/base.sh change (rule 8), so put it in the batch.

**B5. CONTRIBUTING could be read as saying that no profile ships manual pages.** The sentence
ended "`man=yes`, `info=yes`): no profile does", meaning that no profile indexes them; `pi0-pgp`
does ship them (`platform/pi0.sh:21-24`). It was reworded after this review read it.
P10 would also make the code say where a reader looks which systems ship pages.

Smaller doc-versus-code drift, for whoever edits prose:

* `CONTRIBUTING.md:376-377` says that virt takes its xHCI controller from `usb.virt.config`, but no
  virt profile names `usb`.
* `README.md:151` gives `02-root-login.exp` as an example name; the file is `03-root-login.exp`.
* The lfs-build-iteration skill says a no-op build ends with `image (done)`, which P4 shows cannot
  happen.


Proposals
---------

### P1. The framework dispatches components (≈900 lines)

**What is there.** `lib/package.sh:9-35` runs `fetch`, `prepare`, `build`, `install` and `archive`
for every component. Each recipe that has components then tells them apart in every hook, for
example `package/zlib.sh` (46 lines):

```sh
prepare() {
    case $package_component in
        zlib) env ${host:+CHOST=$host} $package_source_dir/configure ... ;;
        *) default_prepare ;;
    esac
}
# ... the same in build(); install() adds `dev) install_component ;;`
```

Across the 46 recipes that do this, an awk count of the `case`/label/`;;`/`default_*`/
`install_component`/`esac` lines gives **926 lines in 137 `case` blocks**. Every `default_prepare`,
`default_build` and `default_install` in the tree is one of these lines (45, 46 and 45 calls). Two
non-main components do real work: `gcc#runtime` and `linux#headers`. Every other one is `dev`, which
is `install_component`.

**Simpler form.** Recipe hooks are for the package's own component. Any other component `C` runs
`C_component` if the recipe defines it, and otherwise `install_component`:

```sh
    if [ "$package_component" = "$package_name" ]; then
        prepare
        build
        _empty_stage; install
    elif command -v ${package_component}_component > /dev/null; then
        _empty_stage; ${package_component}_component
    else
        _empty_stage; install_component
    fi
```

`zlib.sh` becomes three plain hooks of about 20 lines. `linux.sh` gets
`headers_component() { _make_headers headers; _make_headers INSTALL_HDR_PATH=... headers_install; }`,
and `gcc.sh` gets `runtime_component()`. Then nothing calls a `default_*` function any more, so
the indirection in `lib/package.sh:94-143` (`fetch() { default_fetch; }` and the rest) folds into
the hooks themselves, which saves about 20 more lines. No recipe overrides `archive` or `unarchive`
either, so those two can become plain framework functions instead of hooks. With the rewrite, also
fold the six `if docs_wanted; then doc=enable; else doc=disable; fi` lines (gnupg, libassuan,
libgcrypt, libgpg-error, libksba, pinentry) into `--$(doc_switch)-doc`. I tested that helper under
dash and bash with errexit; `command -v` of a shell function works in both.

**Equivalence.** For every component that exists today, the same commands run in the same
directories. The only change is how an unknown component fails: `bash#dev` now fails with "empty
bash dev component" instead of "Unknown package product". A recipe with no `case` (bc, binutils, and
22 others) used to build and archive `bc#foo` as if it were `bc`; now that fails too, which is
better. Component names must be valid shell names, which `dev`, `headers` and `runtime` are. The
table "Where Code Goes" in CONTRIBUTING.md (`case $package_component`) changes with it.

**Cost.** lib/package.sh falls under rule 8 and every recipe under rule 2: every archive becomes
stale, the tools' included. That full rebuild is the reason to batch the other recipe proposals with
this one.

**Verify.** See "Verifying the batch" below. In short: archive manifests of every archive, before and
after, must be identical.

### P2. Dead code and branches (≈110 lines)

Each item was checked with `git grep` across `lfs`, `lib/`, `profile/`, `platform/`, `package/`,
`bin/`, `check/` and `.claude/`.

| Item                                  | Where                                         | Why it is dead                                               |
|---------------------------------------|-----------------------------------------------|--------------------------------------------------------------|
| gmp, mpfr, mpc prepare/build/install  | `package/{gmp,mpfr,mpc}.sh:7-23`              | Only fetch dependencies of gcc; nothing installs them        |
| gcc's `--with-gmp/mpfr/mpc` options   | `package/gcc.sh:48-50`                        | In-tree build; nothing sets `gmp`, `mpfr`, `mpc`             |
| `gcc#libstdc++`                       | `gcc.sh:12-22,96-99`, `libstdcxx_pch`         | No caller installs it                                        |
| `glibc#headers`                       | `glibc.sh:11,76-78`                           | No caller installs it                                        |
| `ncurses#tic`                         | `ncurses.sh:10-13,46-49,65-67`                | No caller installs it (its install even ignores DESTDIR)     |
| The defconfig branch of the kernel    | `linux.sh:45-49,63-65`, `platform/pi0.sh:14`  | Both platforms have `package/linux/<platform>.config`        |
| `fetch_patch`                         | `lib/package.sh:196-201`                      | No caller (it also reads undeclared globals)                 |
| `package_revision`                    | `lib/package.sh:209`                          | No recipe sets it                                            |
| `qemu_system`                         | `platform/pi0.sh:26`, `platform/virt.sh:8,17` | Always equals the default `qemu-system-$target_arch`         |
| `die`                                 | `lib/base.sh:1-10`                            | Only `bail` calls it: `bail() { echo "$@" >&2; exit 1; }`    |
| `mkdir -p ${TMPDIR:-/tmp}`            | `lib/system.sh:24`, `lib/tools.sh:117`        | `lfs:71` already makes `$TMPDIR`, which `lfs:54` always sets |

`qemu_system` also appears in the skill's `qemu-check:65`, with the same fallback, so it changes
with it. The default of `qemu_disk_if` (`lib/qemu.sh:38`) can go too, since both platforms set it.

**Equivalence.** These branches are never taken, so removing them changes nothing at run time.
Removing the defconfig branch leaves the `.config` that `allnoconfig` and the layers produce exactly
as it is.

**Cost.** By itself, P2 makes stale the archives of linux, gcc, glibc, ncurses, gmp, mpfr and mpc,
every archive of every profile (because `platform/*.sh` changes, rule 7), and every archive because
of the lib files (rule 8). Inside the P1 batch it adds nothing.

**Verify.** The `git grep` for each name again; archive manifests; and the resolved kernel `.config`
of pi0-pgp and virt before and after, which must be identical (`kernel-config`).

### P3. Recipe options that nothing sets (≈45 lines)

`${x:+--opt=$x}` expands to nothing when `x` is unset, so an option that no profile, phase or
platform ever sets is a line that does nothing. A script listed every `${x:+` in the recipes for
which no `x=`, `${x:=`, `local x=` or `readonly x=` exists in `lib/`, `profile/`, `platform/`, `lfs`
or the recipe itself:

* util-linux, 21 options: `fsck lsblk losetup swapon kill fallocate mountpoint chfn_chsh login
  nologin su setpriv runuser pylibmount liblastlog2 wall ncurses ncursesw tinfo
  systemdsystemunitdir libmount_mountfd_support`.
* Others: bash `bash_malloc`; binutils `default_hash_style`; coreutils `install_program`,
  `no_install_program`; findutils `localstatedir`; gcc `bootstrap`; glibc `profile`, `werror`; kmod
  `openssl xz zlib zstd`; libxcrypt `failure_tokens`; ncurses `widec`; python `system_expat`;
  shadow `bcrypt`; xz `static`. (The options of gmp, mpfr and mpc go with P2.)

**Equivalence.** Exact. Every configure command line stays character for character the same,
because these words always expanded to nothing. The option defaults that CONTRIBUTING asks for
(`: ${x:=no}`) are not among these and stay.

**Cost.** The archives of those 17 recipes (rule 2); the commit type is `drop`. If the owner sees
these options as a menu for profiles to come, the rule "profiles are written on request, not
speculatively" argues against keeping them.

**Verify.** Run the same grep again. A configure line cannot differ, and the archive manifests
confirm it.

### P4. The image's up-to-date shortcut never fires (≈12 lines)

**What is there.** `lib/image.sh:16-21` skips the image when it, its SBOM and its manifest exist,
the SBOM names the current release (`lfs_sbom_has_release`, `lib/sbom.sh:157-162`), and nothing in
the system tree is newer than the image.

**Why it is dead.** `image/%.img: %-system FORCE` (`Makefile:86`) runs the system build first, every
time. That build writes the profile's files with `envsubst` (`lib/system.sh:173`) and rewrites
`/etc/passwd` with `usermod` (`lib/system.sh:202`) after the archives are extracted, so their
modification time is always later than the image's. Every profile calls `lfs_system_set_root`. The
shortcut can therefore fire only for `./lfs image build` run twice by hand. I verified this by
reading the code, not by running a build.

**Simpler form.** Remove the `elif` branch and `lfs_sbom_has_release`, and inline
`_sbom_release_line` into `_sbom_image_package`. The image step then always builds, which is what it
already does under `make`. No archive becomes stale (rule 1); `make` behaves exactly as before.

**Verify.** Run `make image` twice and check that the log shows the image being made both times,
both before and after the change.

### P5. `meson_prepare` (≈20 lines)

**What is there.** Six meson recipes start their `prepare` with the same three lines: a two-line
comment and `find . -mindepth 1 -delete` (`ccid.sh:11-13`, `dbus.sh:11-13`, `glib.sh:11-13`,
`pcsc-lite.sh:11-13`, `polkit.sh:11-13`, `systemd.sh:11-13`). They then call `meson_cross_file`,
which glib calls as `${host:+meson_cross_file}`. `p11-kit.sh:8`, a tool, does not wipe its build
directory, so it alone can reconfigure stale.

**Simpler form.** `lib/meson.sh` gets
`meson_prepare() { find . -mindepth 1 -delete; [ -z "${host:-}" ] || meson_cross_file; }`, which
states the reason once. All seven recipes call it. A helper that would also run `meson setup` does
not fit: systemd needs `env PATH=... meson setup`, and `PATH` is readonly (`lfs:137,142`).

**Equivalence.** The same commands for the six recipes. p11-kit gains the wipe, which removes the
stale-reconfigure risk that CONTRIBUTING warns about. Rename the grep of `bin/invalidate:257` (rule
5) with it.

**Cost.** The seven meson recipes (rules 5 and 2).

### P6. The CMake cross settings in one helper (≈10 lines)

`package/libcbor.sh:14-24` and `package/libfido2.sh:17-26` repeat the same nine
`-DCMAKE_SYSTEM_*`/`-DCMAKE_FIND_ROOT_PATH*` arguments. CMake's own mechanism for this is a
toolchain file. A `cmake_toolchain_file` in a new `lib/cmake.sh` would write it, the way
`meson_cross_file` writes meson's cross file, and each recipe would pass
`${host:+-DCMAKE_TOOLCHAIN_FILE=$PWD/toolchain.cmake}`. libfido2 does not set `CMAKE_CXX_COMPILER`
today; a toolchain file that sets it is harmless for a C-only project, but check its archive
manifest. **Cost:** a new lib file falls under rule 8 (every archive) unless `bin/invalidate` gets a
rule for it like rule 5. Inside the P1 batch that costs nothing extra.

### P7. CI: one matrix instead of three workflows (≈85 lines)

**What is there.** `virt.yaml`, `pi0-pgp.yaml` and `virt-busybox.yaml` (29 lines each) are the same
file with a different profile name, and `ci.yaml:41-57` calls each one. The list of profiles is also
in `check/lint:15` (`ci_profiles`, plus a check that each workflow file exists) and in
`vulnerabilities.yaml:32`.

**Simpler form.** `ci.yaml` calls `system.yaml` itself, with
`strategy: { fail-fast: false, matrix: { profile: [...], docker: [false, true] } }`. GitHub
documents matrices for jobs that call reusable workflows. That removes the three files and the two
lint checks. A small job could also compute the list from `profile/*.sh`
(`ls profile/*.sh | ... | jq -Rsc`) for `fromJSON`, both here and in `vulnerabilities.yaml`. A new
profile would then be in CI without any edit.

**Trade-off.** The check names change (`system (virt, false) / ...`). Branch protection that names
checks would need updating; I found none in the tree, so this is unverified. `fail-fast: false`
keeps one failing profile from stopping the others. The nesting gets one level shallower.

**Verify.** Dispatch `ci.yaml` once and compare the jobs that run.

### P8. Compose and Dockerfile lists stated once (≈65 lines)

* **Compose mounts.** Each bind mount in `docker-compose.yaml` takes three lines (26 mounts). The
  short syntax `- ./lib:/mnt/lfs/lib` takes one and saves about 50 lines. The one behaviour
  difference: short syntax creates a missing host path, where long syntax fails. The Makefile
  creates them first (`Makefile:136`), except `work/boot` for `docker-dev`. Unverified: run
  `make docker-test` from a clean clone.
* **Dockerfile directories.** `Dockerfile.bootstrap:25-45` and `Dockerfile.dev:31-51` list the
  same nine directories twice each, once for `mkdir` and once for `chown`.
  `RUN install -d -o lfs -g lfs /mnt/lfs /mnt/lfs/download ...` states the list once, with the same
  modes and owners. That is safe. Going further is unverified: probably only `/mnt/lfs`, `work` and
  `tools` need to exist, since the others are bind mounts, whose mount points Docker makes. Test it
  before relying on it.
* **Cost.** Dockerfile.bootstrap and docker-compose.yaml are inputs under `--docker`, so
  `make docker-invalidate` drops every Docker archive. Dockerfile.dev is no input.
* Leave the separate bind mounts as they are, rather than mounting `.`: that is what keeps a build's
  inputs to the paths that `bin/invalidate` knows.

### P9. Per-build variables kept out of archives (≈15 lines; fixes B1, B2)

Nothing sets `LFS_MACHINE`, `LFS_VERSION_CODENAME`, `LFS_RELEASE_TYPE`, `LFS_DISTRIB_CODENAME` or
`LFS_DISTRIB_DESCRIPTION`: not the Makefile, not CI, not the documentation's examples. The cleanest
fix is to drop all five. system-files then writes the constant defaults it writes today
(`local`, `development`, `Linux From Scratch`); linux.sh loses line 66; the lists in `lfs:59-64`,
in `lfs help` and in `docker-compose.yaml:56-59` shrink. That is a `drop!` (the environment of `lfs`
is the interface).

If the owner wants to keep them, move the four os-release fields into `stage_root`, next to
`LFS_RELEASE`'s (`lib/image.sh:212-220`), and write `LFS_MACHINE` as `/etc/hostname` there. Then
nothing per-build lives in an archive. **Cost:** system-files and linux (rule 2), and every archive
if `lfs` changes (rule 8, nothing extra in the batch).

### P10. `man` and `info` set by the profile (≈0 lines; fixes B5)

`platform/pi0.sh:21-24` sets `man=yes info=yes` for "the systems of this platform", which is a
policy that lives outside the profile. In fact only pi0-pgp installs mandoc and texinfo.
CONTRIBUTING says that a profile sets `=yes` for the features it uses. Move the two settings to the
top of `profile/pi0-pgp.sh`. Then the `man=no info=no` in `lfs_tools_bootstrap` and `lfs_tools_build`
(`lib/tools.sh:37,127`) are defaults and can go; those in `lfs_tools_install` and
`lfs_toolchain_install` stay, as they run inside the profile.

**Equivalence.** Every package installs with the same values. The documentation index runs in the
profile's subshell (`lib/system.sh:58-62`). system-files, which is installed before the profile,
does not read `man`. **Cost:** every pi0-pgp archive (rules 3 and 7); the contents are unchanged.
**Verify:** `env-trace` on `lib/tools.sh`, and archive manifests.

### P11. Test helpers for repeated idioms (≈20 lines)

* `lassign [run X] output status; expect_match $output P what; if {$status == 0} {fail ...}`
  appears 6 times (pi0-pgp tests 06, 09, 22 twice, 24, 26). A proc
  `expect_refused {line pattern what}` in `check/test` turns each into one line.
* `stick` (`check/test:98-109`) and test 24 (lines 25-30) both write a sparse blank disk.
  `blank_disk name MiB` serves both.
* The 8 wait loops `n=0; while ...; do sleep 1; ...; done; ...` could become a `wait_for` proc that
  builds the shell line. This gains clarity more than lines.
* Optional: `03-root-login.exp` (in all three profiles) is covered by the next test that logs root
  in, and a failed login there reports just as clearly. Removing it saves three files. The case for
  keeping it is the rule "a test is about one thing".

No archive is affected. **Verify:** `make <profile>-test` for the three profiles.

### P12. systemd's sysctl file shipped as a file (≈0 lines)

`package/systemd.sh:146-157` writes `50-default.conf` with a heredoc. CONTRIBUTING's rule is "files
shipped verbatim: `package/<name>/<path as installed>`". The `cp -rv $package_files_dir/etc
$package_files_dir/usr` at line 141 already copies `package/systemd/usr` after `ninja install`, so
`package/systemd/usr/lib/sysctl.d/50-default.conf` would replace upstream's file in the same way,
with the same mode (0644). The recipe loses 13 lines and the file gains them. **Cost:** systemd
(rule 2). The sentence at `CONTRIBUTING.md:351` changes with it.

### P13. Fragments that no profile names, and a doubled option (≈60 lines)

* BusyBox: `e2fsprogs`, `klibc-utils`, `mailutils`, `modutils` and `runit.config` are in no
  profile's `applets` (about 45 lines; `profile/virt-busybox.md:93-95` lists them on purpose).
* Kernel: `serial-console.arm64.config`, `serial-console.x86_64.config` and `usb.virt.config` are
  parts of capabilities that only pi0-pgp (arm) names.
* `CONFIG_TMPFS` and `CONFIG_TMPFS_POSIX_ACL` are in both `base.config:52-53` and
  `systemd.config:44-45`. Every system gets base, and CONTRIBUTING asks for "each bit once": drop
  the pair from `systemd.config`.

This is the owner's call: the files are a catalogue for profiles to come, which the rule "not
speculatively" argues against. **Cost:** busybox and linux (rule 2); the resolved `.config` is
unchanged, so check it with `kernel-config`.

### P14. The layout branches of `image.sh` (≈10 lines)

Both platforms set `image_layout`, so the seven `${image_layout:-pi}` defaults
(`lib/image.sh:42,84,93,131,151,168,238`) can be plain `$image_layout`. The two heredocs of
`create_partitions` (`:92-110`) differ by one line: print the common lines once, and add the boot
partition's line for the Pi layout. The two `tar` lines of `stage_root` (`:168-175`) differ by
`--exclude=./boot`. **Cost:** none (rule 1). **Verify:** build both images and compare `sfdisk -d`
and the manifests (`<key>.root.txt`, `<key>.boot.txt`). The images themselves are not byte for byte
reproducible (machine ID).

### P15. The root's kernel arguments in one place (≈3 lines)

`rootfstype=btrfs rootflags=subvol=root/$root_volume ... rootwait` is written in `package/boot.sh:25`
for the Pi and in `lib/qemu.sh:33` for virt. virt's `qemu_append` also carries what is the kernel's
command line, not QEMU's (`console=hvc0 root=/dev/vda1`). The uniform form: every platform has a
`kernel_cmdline`, one framework function gives the root's arguments, `boot.sh` writes both, and
`qemu.sh` uses `cmdline.txt` if there is one, else the same two, and then adds `qemu_append`.
**Cost:** boot and every virt archive (rule 7). Low value; do it only within the batch.

### P16. Static accounts of daemons that are not built (≈18 lines)

`package/systemd/etc/passwd` and `group` have accounts for systemd-journal-gateway, -remote and
-upload, systemd-network, -resolve, -timesync, -coredump and -oom, and uuidd. The recipe turns all of
these off (`remote=disabled`, `networkd`, `resolve`, `timesyncd`, `coredump`, `oomd` false), and
neither util-linux nor e2fsprogs builds uuidd. That is 9 lines in each file. Keep the groups that
udev rules and tmpfiles use (`kvm`, `render`, `sgx`, `input`, `adm`, `wheel`, `utmp` and the rest).
Unverified: grep the built system tree for the names, then boot and check against the baseline
(`check-baseline`) that nothing new warns.

### P17. One expect harness for the QEMU skill (≈35 lines)

`boot.tcl`, `qemu-run.exp` and `examples/user-commands.exp` re-implement the boot, login and marker
logic of `check/test`. `user-commands.exp:11-26` is `boot.tcl` with another account. Let `boot.tcl`
take `LOGIN_USER`, and `user-commands.exp` source it; better still, move `check/test`'s procedures
into a file that both source. No archive is affected.

### P18. Small leftovers (≈20 lines)

* `check/lint:104-144` loops over `profile/*.sh` four times; one loop does it all.
* `Makefile:1-19`: GNU make takes no patterns in `.PHONY`, so `%-system`, `%-qemu`, `%-test` and the
  `docker-%` entries name nothing.
* The tag lookup `git describe --tags --abbrev=0 --match '[0-9]*.[0-9]*.[0-9]*'` is written in
  `bin/version:32`, `bin/release:130` and `check/commit-messages:112`; `bin/release` could ask
  `bin/version` for it.
* `lfs:146` makes `SSL_CERT_FILE` readonly but not `SSL_CERT_DIR`.
* `${LFS_STATE_DIR:-}` and the other directories at `lfs:56-58` are already set by `lfs:28-43`.
* `package/python.sh:9` (`build_python`), `lib/python.sh:40,49,60` and `python/cryptography.sh:25`
  spell `$LFS_TOOL_DIR/usr/bin/python3` five times.
* `phase.yaml` spells the cache fingerprint (`find ... -printf | sort | sha256sum`) twice
  (lines 157-158, 219).


Verifying the Batch
-------------------

For P1 together with P2, P3, P5, P6, P9, P10, P12, P13, P15 and P16, following the
lfs-build-iteration skill:

1. Before the change, copy `archive/` away and write a manifest of every archive
   (`archive-manifest.py`).
2. Make the change. Run `env-trace` on the changed lib files to show that the environment of every
   install is the same, then run `make docker-invalidate` (the owner's step) and rebuild tools and
   all three profiles.
3. Diff the manifests archive by archive. They should be identical, except for the system-files
   archive (P9, if the variables move or go) and for the files P12 and P16 move or remove. Diff the
   resolved kernel `.config` files.
4. Boot with `make <profile>-test` and `check-baseline` for each profile.


Same Fact, Several Places
-------------------------

What remains after the proposals, so that nobody adds a fourth copy:

* The `LFS_*` variables: `lfs:53-68`, `lfs help`, `docker-compose.yaml:48-59` (already drifted, B1).
* The host's packages: `README.md:19-35`, `Dockerfile.bootstrap:12-22`, `Dockerfile.dev:4-16`,
  `phase.yaml:75-76` (which says it copies the Dockerfile).
* The commit types: `check/commit-messages:25`, `bin/version:39-44`, CONTRIBUTING's table,
  `docs/commit-messages.md`.
* The regular account's UID 1000 and the `users` group's 999: `lib/system.sh:239`,
  `package/systemd/etc/group`, and the two `mnt-*.mount` units. This one earns it: a unit cannot
  look the IDs up.


What Earns Its Complexity
-------------------------

These look heavy but carry their weight; do not "simplify" them.

* The environment scrub in `lfs:47-69` (`exec env -`): it is what keeps the host out of builds.
* The subshell per package, with readonly package variables (`lib/package.sh:84-237`).
* The digest of each tool extracted into `tools/.installed` (`lib/package.sh:164-179`): parallel
  builds would otherwise rewrite running programs.
* `bin/invalidate`'s path rules and `.commit` record per key: blunt by design, and the comment says
  why (a few archives too many are cheaper than a stale one).
* The separate bind mounts in Compose (see P8), and the per-profile keys that make profiles share
  nothing.
* The SBOM in POSIX shell with sed and awk (`lib/sbom.sh`): the containers have no jq.
* The image put together from trees with nothing mounted (`mkfs.btrfs --rootdir`, `mcopy`), so that
  the build needs no loop devices.
* `apply_patch`'s stamps, the rtld specs of gcc (`gcc.sh:123-130`), the `cargo rustc --lib -- -C
  linker` of cryptography, and the sysconfigdata variables of `python_wheel`: each answers a
  cross-compiling trap that CONTRIBUTING describes.
* The custom fetches of tzdata (two tarballs into one directory) and ca-certificates (a `.txt`).
* `check/kernel-vex` and the two Grype runs in `check/vulnerabilities`: the VEX document needs the
  raw findings first.
* In `check/test`, markers written from split strings, and an overlay next to a symlink of the
  image, so that the image is never written.
