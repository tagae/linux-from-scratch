GitHub Appeal
=============

How the repository could look to someone who opens it on GitHub for the first time, and what to
change in its versioned files so that it reads as professional and lean. It covers what such a
visitor sees, in order: the file list, the README's first screen, then the pages they click. It
builds on the trimmed text of the `docs` branch, assumed merged, and on `main` as of 2026-11-26.
[If the `docs` Branch Is Not Merged](#if-the-docs-branch-is-not-merged) says where the advice
differs. Every figure was measured from the built images. [Figures](#figures) says how.


Summary
-------

A visitor today reads the title "Linux From Scratch", one line ("Build Linux From Scratch and
additional packages"), and then a list of requirements. They are not told what the project makes,
what sets it apart from the book it is named after, or that it ships an air-gapped OpenPGP computer
for the Raspberry Pi Zero. The project has the material to answer all three. It has measured
images, test suites that pass, an SBOM, and a profile short enough to show in full. Most of the
work is to put that material first.

| Rank | Change                                                         | Effect | Effort    |
|-----:|----------------------------------------------------------------|--------|-----------|
|    1 | README opening: what it is, a table of the systems, a run      | High   | 1 hour    |
|    2 | README body: tables for targets and settings, fewer sections   | Medium | 1-2 hours |
|    3 | File list: drop `TODO.md`; dated reports leave `docs/`         | Medium | Minutes   |
|    4 | Badges: CI's, next to the vulnerability scan's                 | Medium | Minutes   |
|    5 | `.github/SECURITY.md`                                          | Medium | Minutes   |
|    6 | `profile/pi0-pgp.md`: what you need, and the serial wiring     | Medium | 30 min    |
|    7 | `CONTRIBUTING.md`: an opening that says how to contribute      | Medium | Minutes   |
|    8 | Licence: what MIT covers, and what it does not                 | Low    | Minutes   |
|    9 | A first release, `1.0.0`                                       | Low    | Minutes   |

Do 1, 3 and 4 first. Together they change everything on the first screen in about an hour. Then do
5 to 7, which serve the visitor who has decided to look closer.

None of these changes invalidates an archive. The README, `CONTRIBUTING.md`, `profile/*.md`,
`docs/` and `.github/SECURITY.md` are not build inputs (the header of `bin/invalidate`), and CI
skips pushes that change only Markdown. The one missing figure is the time of a cold build. Only a
cold build can measure it, so it is left to the owner ([Owner's Decisions](#owners-decisions)).


1. The README's First Screen
----------------------------

A visitor wants to know, in this order: what this is, what it produces, whether it works, and how
to try it. The draft below answers each with something concrete. It gives one paragraph of plain
description and a table of the three systems with measured figures. Then come one command and the
real output of that command, cut from a run on 2026-11-26. The draft replaces everything above
"Requirements" in the README, together with "Supported Platforms" and the first half of
"Profiles".

````markdown
Linux From Scratch
==================

[![CI](https://github.com/tagae/linux-from-scratch/actions/workflows/ci.yaml/badge.svg)](https://github.com/tagae/linux-from-scratch/actions/workflows/ci.yaml)
[![Vulnerability scan](https://github.com/tagae/linux-from-scratch/actions/workflows/vulnerabilities.yaml/badge.svg)](https://github.com/tagae/linux-from-scratch/actions/workflows/vulnerabilities.yaml)

Complete Linux systems built from source by a small POSIX shell framework, after the [Linux From
Scratch] and [Beyond Linux From Scratch] books. From a host's compiler, it builds its own tools,
then a cross toolchain, then the kernel, the init system and every program of the system. The
result is a disk image that boots on a Raspberry Pi Zero or in QEMU. Each image comes with an SPDX
bill of materials, and is booted and tested before the build counts as done.

A system is one shell file, its *profile*. Three come with the framework:

| Profile        | Runs on           | What it is                     | Packages |   Image | Tests |
|----------------|-------------------|--------------------------------|---------:|--------:|------:|
| [virt-busybox] | QEMU              | BusyBox on musl                |        3 |  17 MiB |     8 |
| [virt]         | QEMU              | systemd on glibc, minimal      |       14 |  57 MiB |    10 |
| [pi0-pgp]      | Raspberry Pi Zero | Air-gapped OpenPGP workstation |       62 | 225 MiB |    28 |

The packages are those that the image's SBOM lists, and the tests run on one boot of the image.
QEMU runs the `virt` profiles with the host's architecture, aarch64 or x86_64. `virt` is the
default.

[virt-busybox]: profile/virt-busybox.md
[virt]: profile/virt.md
[pi0-pgp]: profile/pi0-pgp.md
[Linux From Scratch]: https://www.linuxfromscratch.org/lfs/view/systemd/
[Beyond Linux From Scratch]: https://www.linuxfromscratch.org/blfs/view/stable-systemd/


Quick Start
-----------

On Linux or macOS, you need Docker Compose to build, and QEMU 11.1 or later and `expect` to boot
and test ([Requirements](#requirements)). Then run:

```shell
make docker-test
```

This builds the tools in containers, then the `virt` system and its image. It then boots the image
in QEMU and runs its tests. The first run compiles everything, which takes <MEASURED TIME>. Later
runs reuse the archives of the packages already built. The run ends with the tests:

```
check/test virt
PASS 01-boot (3 s)
PASS 02-console-quiet (10 s)
PASS 03-root-login (3 s)
PASS 04-issue-motd (2 s)
PASS 05-system-status (2 s)
PASS 06-system-facts (3 s)
PASS 07-bus (2 s)
PASS 08-sandbox (3 s)
PASS 09-restart (16 s)
PASS 99-poweroff (0 s)
virt: 10 tests passed
```

`make docker-pi0-pgp-test` does the same for the Pi system, in QEMU's emulation of the Zero. Its
[page](profile/pi0-pgp.md#quick-start) tells how to write the image to an SD card. On a Linux host
that meets the [requirements](#requirements), `make test` builds without containers.
````

Why it is built this way:

* **The title stays.** Renaming the repository is a GitHub setting, and an H1 that differs from the
  repository's name confuses more than it helps. Instead, the first sentence says how the project
  relates to the books: it is built *after* them, and it is not the books.
* **A table instead of "Supported Platforms".** The table answers "what does it make?" with real
  sizes. It also replaces the platform table, because the "Runs on" column carries the same fact.
  The rows are sorted by size, so the table reads as a scale from 17 MiB to 225 MiB.
* **Reference links** (`[virt]`) keep the table's columns aligned in plain text and under 100
  columns wide.
* **The transcript is real**, and is the evidence for "booted and tested". Its test names already
  say what the tests check.
* **Docker comes first**, because it is the only path that works on macOS as well as Linux.

Below the Quick Start, a short section shows how the framework works. It has a diagram of how a
profile becomes an image, a whole profile shown as the proof that a system is one shell file, and
the properties that set the project apart. Each claim was checked against the code.

````markdown
How It Works
------------

```
host's compiler (or the container of Dockerfile.bootstrap)
  │
  │ lfs tools bootstrap   native toolchain, temporary tools                 tools/
  ▼
the built tools alone: nothing of the host is on PATH from here on
  │
  │ lfs tools build       Python, Perl, CMake, kmod, btrfs-progs...         tools/
  │ lfs system build      cross binutils, gcc, and glibc or musl            tools/
  │                       each package of profile/<p>.sh, as an archive     archive/<p>/
  │                       unpacked into the system tree                     work/<p>/system
  │ lfs image build       btrfs root (and the Pi's FAT boot partition),     image/<p>.img
  │                       SBOM and file manifests                           image/<p>.spdx.json
  ▼
check/test <p>            boots the image in QEMU, runs profile/<p>/test/*.exp on its console
```

A profile lists the packages of its system in the order they are installed, with each package's
options where it is installed. This is the whole of `virt-busybox`:

```shell
# A bare-bones BusyBox virtual machine.

lfs_system_toolchain musl

(
    applets="archival console-tools coreutils debianutils editors findutils init loginutils"
    applets="$applets miscutils networking procps shell util-linux"
    lfs_system_install busybox
)

( capabilities="btrfs console devtmpfs hardening"; lfs_system_install linux )

# root logs in with BusyBox's sh, and with no password unless LFS_ROOT_PASSWORD sets one.
lfs_system_set_root
```

* **Nothing of the host.** `lfs` restarts itself in an empty environment that keeps only `PATH`,
  `TMPDIR` and its `LFS_*` variables. After the bootstrap, `PATH` holds only the tools that the
  framework built.
* **Pinned sources.** Every download has its SHA-256 in its recipe, and every patch is in the
  repository.
* **Kernels from nothing.** Each kernel starts from `allnoconfig`. Every option it gets comes from a
  file of `package/linux/`, which gives the option's reason.
* **Accounted for.** Each image has an SPDX 2.3 document that gives the image's hash and each
  package's licence and CPE, and a manifest of every file. After each CI run, Grype scans the
  documents of CI's images for known vulnerabilities.
* **Tested by booting.** CI builds each profile on a Linux runner and through Docker Compose. It
  then boots each image in QEMU and runs the profile's tests.
* **Small.** The framework is about 1,200 lines of POSIX shell (`lfs` and `lib/`, without comments
  or blank lines), and there are 101 package recipes.

This is not a distribution. There are no binary packages, no package manager and no updates in
place: a system changes by being rebuilt. Localisation is not supported. The Raspberry Pi's boot
firmware is Broadcom's binary, and is the one part of an image that is not built from source.
````

The last paragraph matters as much as the bullets. A reader who learns the limits up front trusts
the claims above them. It is also the one place where "every program built from source" needs its
exception: the Pi's firmware. The Rust compiler used to build packages is also a prebuilt seed, but
it stays on the build machine. If you prefer to list it, add "The Rust compiler that builds the
`cryptography` package is a prebuilt seed, kept out of the image."


2. The Rest of the README
-------------------------

After the opening, the README serves people who build. Two tables can replace four prose sections.
Text that serves people who write profiles belongs in `CONTRIBUTING.md`.

| Section (docs branch) | Proposal                                                               |
|-----------------------|------------------------------------------------------------------------|
| Opening, Quick Start  | Replace them with the draft of section 1                               |
| Requirements          | Keep as it is, after How It Works                                      |
| Supported Platforms   | Drop it: the profile table's "Runs on" column says the same            |
| Profiles              | Fold it into the opening; keep the naming rule in Building             |
| Kernel Capabilities   | Move it to CONTRIBUTING, Kernel, for those who write a profile         |
| Time & Date           | Make it a row of the settings table; the Pi's clock is in its own page |
| Localisation          | Make it one sentence of the opening's last paragraph                   |
| Users                 | Make it rows of the settings table                                     |
| (new) Building        | The two tables below                                                   |
| Tests                 | Keep it                                                                |
| Disk Images           | Keep it, and add writing to a device (now in CONTRIBUTING, Images)     |
| (new) Licence         | See section 8                                                          |

````markdown
Building
--------

Each step has a target per profile. The targets with the `docker-` prefix build through Docker
Compose: `docker-<profile>-system`, `docker-image/<profile>.img` and `docker-<profile>-test`.

| Target                     | Does                                                             |
|----------------------------|------------------------------------------------------------------|
| `make <profile>-system`    | Builds the tools and the system tree                             |
| `make image/<profile>.img` | The same, then makes the image, its SBOM and its manifests       |
| `make <profile>-test`      | The same, then boots the image in QEMU and runs its tests        |
| `make <profile>-qemu`      | The same, then boots the image on the terminal, to log in        |
| `make invalidate`          | Deletes the archives made stale by changes since its last run    |

A package is compiled only if it has no archive, so a second build takes minutes.
`make system`, `make image`, `make qemu` and `make test` build `LFS_PROFILE`. A profile is named
`<platform>[-<name>]` after the platform it runs on, and its name is the key of everything built
for it. Several profiles can be built at once: `make -j docker-test docker-pi0-pgp-test`.

| Setting             | Default | Gives                                                         |
|---------------------|---------|---------------------------------------------------------------|
| `LFS_PROFILE`       | `virt`  | The system that `make test`, `make image`... build            |
| `LFS_TIMEZONE`      | `UTC`   | The image's time zone, in a profile that installs `tzdata`    |
| `LFS_USER`          | `$USER` | The regular account, in a profile that has one                |
| `LFS_PASSWORD`      | none    | That account's password; with none, it logs in without one    |
| `LFS_ROOT_PASSWORD` | none    | root's password; with none, root logs in without one          |
| `LFS_QEMU_EXTRA`    | none    | More arguments for QEMU, such as `-device usb-ccid`           |

The clock of a system with systemd never starts earlier than the time its image was made.
````

Each fact in the drafts was checked against the code. The targets and the `docker-` targets are
those of the `Makefile`: there is no `docker-<profile>-qemu`. The defaults come from the `Makefile`
(`LFS_PROFILE ?= virt`, `LFS_USER ?= $(USER)`) and from the usage text of `lfs`. "Only the packages
that have no archive" follows the rule that a recipe runs again only when its archive is gone.

The reference half of the README gets shorter, and the README then mixes no audiences: users read
the README, and authors read CONTRIBUTING.


3. The File List
----------------

The file list is the first thing on the page. At the root, it shows 13 files and 10 directories.
Two root files and part of `docs/` are noise:

* **`TODO.md`** holds a single open design question (a `devroot` tree in place of a sysroot). In a
  root listing, a TODO file reads as "unfinished". Remove it, and keep the question wherever the
  owner keeps notes.
* **Dated reports in `docs/`** (`profile-ideas.md`, `security-review.md`,
  `simplification-review.md`, and this file). Each one reviews the tree at a given commit, so each
  goes stale with the next change. That contradicts the project's own rule that text should be
  timeless. Delete each report once its findings are acted on or declined; git history keeps it.
  Two parts are worth keeping before then:
  * the Threat Model of the security review, which belongs in `profile/pi0-pgp.md`, Privacy. That
    page is what a reader of the profile will judge it by.
  * the review's finding S1, which belongs in the same page, in What You Need (section 6). The
    computer at the other end of the serial adapter is inside the air gap.

  This leaves `docs/` with the documents that describe the project as it is:
  `commit-messages.md`, `commit-template.txt` and `sbom-design.md`.

Leave the rest. The three `Dockerfile.*` files and `docker-compose.yaml` could move into a
`docker/` directory, which would save the root three entries. But every `docker compose` call would
then need `-f`, and `bin/invalidate --docker` treats these files as build inputs, so the move would
drop every Docker archive. That gain does not justify the change. `.tcl-ls/` and `tcllsrc.tcl`
configure the editor's Tcl language server, which reads its file from the root. `.claude/` holds
the build and test skills that the project relies on.


4. Badges
---------

A badge is information only when it can change. The README has one, the vulnerability scan. That
badge turns red when an image has a high or critical finding for which a fixed version exists:
real information, but about upstream packages as much as about this project. The fact a visitor
wants first is whether the systems build and boot, and that is CI's badge. Put CI's badge first and
keep the scan's next to it, both on one line, as in the draft of section 1.

Add no other badge. The sidebar already shows the licence and the languages, and badges for stars,
"made with" or a version would only repeat it.


5. A Security Policy
--------------------

`pi0-pgp` is a security product: it is where someone makes the keys that they will trust for
years. A visitor of such a project looks for a security policy. GitHub links a `SECURITY.md` from
the repository's sidebar, and reads it from `.github/`, which keeps the root lean. A draft for
`.github/SECURITY.md`:

````markdown
Security
========

Report a vulnerability in the framework, or in a system it builds, privately to <CONTACT>, and not
in a public issue.

The threat model of `pi0-pgp`, and what that system does not protect against, are in its
[Privacy](../profile/pi0-pgp.md#privacy) section. Known vulnerabilities of upstream packages are
found by scanning each image's SBOM: `make vulnerability-check` runs the scan locally, and CI runs
it after every build. A package is updated once its upstream releases a fix.
````

The contact is the owner's decision. It can be an address, or GitHub's private vulnerability
reporting, which is a setting outside this report. The last sentence states the project's existing
practice: findings wait for an upstream release, with no local patches or ignore entries.


6. The `pi0-pgp` Page
---------------------

This page is the project's showcase, and the trimmed version opens well: a title that says what
the system is, and two uses. What it lacks is the one list that someone who wants to build the
system looks for first, the hardware. It also does not show how to reach the only console. Insert
this before Quick Start:

````markdown
What You Need
-------------

* A Raspberry Pi Zero (not a Zero W, which has a radio), with a header soldered to its GPIO pads,
  and a micro-SD card.
* A USB-to-serial adapter with 3.3 V logic, for the console, the only one that the system has:

  | Adapter | Pi Zero header        |
  |---------|-----------------------|
  | GND     | pin 6, ground         |
  | RX      | pin 8, GPIO 14 (TXD)  |
  | TX      | pin 10, GPIO 15 (RXD) |

  The console runs at 115200 baud (`screen /dev/ttyUSB0 115200` on Linux). The computer at the
  other end sees and can type everything that the session does, passphrases included: it is inside
  the air gap, and must be trusted as much as the Pi.
* A micro-USB OTG adapter and a USB hub on the port marked *USB* ([USB Storage](#usb-storage)).
* A USB stick for the keys
  ([Formatting the Stick for the Keys](#formatting-the-stick-for-the-keys)), and a YubiKey to take
  the subkeys.
````

Checked against the code: the console is `ttyAMA0,115200`, the PL011 UART (`platform/pi0.sh`), and
`config.txt` has `enable_uart=1` (`package/boot.sh`). On the 40-pin header, the PL011 UART is GPIO
14 and 15, pins 8 and 10, and pin 6 is ground. The warning about the serial host is finding S1 of
the security review. It belongs here, where the reader chooses the hardware.

The board also takes no network cable or display, and the page says so already (Privacy). No photo
is proposed. A photo of a Pi with a hub and an adapter shows what any reader can picture, and the
three-row table above is the information that a photo would hide.


7. CONTRIBUTING's Opening
-------------------------

GitHub links `CONTRIBUTING.md` from the README and from every new issue and pull request. Its first
screen today is a list of directories. That is good reference material, but it does not tell a
would-be contributor what is welcome or what to run before proposing a change. Insert this between
the H1 and Overview:

````markdown
Fixes are welcome as pull requests against `main`, and problems as issues that name the profile,
the host and the step that failed. A new profile, a new package or a change to the framework starts
as an issue, as [Framework Changes](#framework-changes) asks.

Before a pull request, run:

```shell
make lint commit-lint      # shell code, recipes, profiles and commit messages
make <profile>-test        # for each profile that the change touches: build, boot, test
```

Commit messages follow [docs/commit-messages.md](docs/commit-messages.md) (`fix: ...`).
[Before Calling a Change Done](#before-calling-a-change-done) is the full checklist. The rest of
this file explains how the framework is put together, and its conventions.
````

Whether to invite pull requests at all is the owner's decision. If the answer is no, the first
sentence becomes: "Issues are welcome; this is a personal project, and pull requests may not be
merged."

Keep the rest of the file whole. Splitting it into a short guide and a framework manual would add a
file and a click for little gain, because here contributing means writing recipes and profiles, and
the manual says how. The split would also rewrite comments that cite "CONTRIBUTING.md, <section>"
in `lib/system.sh` and in six recipes (btrfs-progs, ccid, dbus, glib, pcsc-lite, polkit), and so
drop every system archive. Two smaller edits help a reader skimming the file. Set Overview as an
aligned two-column block (path, then purpose) instead of bullets. Move the one-item "Gotchas"
section into Conventions, next to "All shell code should be POSIX compliant".


8. Licence
----------

`LICENSE` is MIT, and GitHub shows it in the sidebar. A careful visitor will wonder what it covers.
The images hold GPL software, and `package/` holds patches to glibc, Python and Linux, which stay
under the licences of what they patch. One paragraph at the end of the README settles the question:

````markdown
Licence
-------

The framework is under the [MIT licence](LICENSE). The patches in `package/` are under the licences
of the software they patch, and the images hold software under the licences that their SBOMs list.
````

The cleanest choice is to keep MIT and add this paragraph. It costs nothing, and it states what is
already true. Moving to a copyleft licence would change nothing for the images, and would only
narrow who can reuse the framework.


9. A First Release
------------------

Today the only tag is the baseline `0.0.0`, and images report a revision such as
`1.0.0-r<hash>`. `bin/version` computes `1.0.0` as the next version, because the history holds
breaking commits since the baseline. Tagging that version gives the README and the images a version
to name. GitHub then shows one tag with release notes, which `bin/release` already writes into the
annotated tag from the commit summaries. The steps are `bin/release --dry-run`, then `bin/release`
and `git push github 1.0.0`. Do it after sections 1 to 8 land, so that the release carries them. By
SemVer, 1.0 declares the interface stable, and the next breaking change becomes 2.0.0. The commit
types already handle that.


Not Recommended
---------------

Each of these would make the repository look busier without telling a visitor anything new:

* **`CODE_OF_CONDUCT.md`, issue and pull-request templates, `SUPPORT.md`, `FUNDING.yml`.** With
  one maintainer and no community spaces, they are templates that say nothing about this project.
  Add templates only if the issues that arrive need them.
* **`CHANGELOG.md`.** The annotated tags carry the release notes, so a changelog would repeat them.
* **A logo, a banner, an animated boot, emoji, or more badges.** The console is text, and a text
  transcript is smaller than a screenshot, can be searched, copied and diffed, and is honest about
  timing.
* **A line of versions** ("Linux 7.3.1, glibc 2.44, GCC 16.2.0"). It goes stale with every package
  update, which is an `upgrade` commit that nobody would think to pair with a README edit. The SBOM
  has the versions.
* **`profile/README.md`.** It would repeat the README's table, and the README links each profile's
  page directly.
* **`.gitattributes` for the language bar.** The bar is already accurate: shell outweighs the Tcl
  tests about eight to one, and the diffs and kernel fragments do not count.


If the `docs` Branch Is Not Merged
---------------------------------

The drafts above fit `main` just as well. `main` also has defects that the trim fixes, so without
the merge, fix at least these:

* The Requirements section of `main` says that Docker users "can skip these requirements". They
  cannot: QEMU and `expect` still run on the host.
* There are two typos: "dedisred" (Time & Date) and "Capabilities can also differ platform".
* The profile documents are not linked from the README. Section 1's table links them.
* The kernel capability table is out of order (`hidraw` comes last). Section 2 moves the table, so
  sort it in its new place.

The CONTRIBUTING opening (section 7) and What You Need (section 6) fit both versions of those
files.


Owner's Decisions
-----------------

| Decision                 | Recommendation                              | Cost                   |
|--------------------------|---------------------------------------------|------------------------|
| Inviting pull requests   | Invite fixes; new work starts as an issue   | Reviewing what arrives |
| The security contact     | An address, or GitHub's private reporting   | Answering privately    |
| The licence              | Keep MIT; add the paragraph of section 8    | None                   |
| Releasing `1.0.0`        | After this round of documentation           | SemVer stability       |
| The cold build time      | Measure a cold build or a `cold` CI run     | One full build         |
| Dated reports in `docs/` | Delete once acted on; keep the threat model | None; git keeps them   |


Figures
-------

The figures were measured on 2026-11-26 from the images in `image/`, whose build inputs (`lib`,
`package`, `profile/*.sh`, `platform` and `lfs`) equal those of the `main` that this document builds
on. Nothing in `image/` was written.

| Profile        | Image (bytes) | Image   | SBOM packages | Files  | Tests | Suite, booted |
|----------------|--------------:|--------:|--------------:|-------:|------:|--------------:|
| `virt-busybox` |    17,825,792 |  17 MiB |             3 |    237 |     8 |          30 s |
| `virt`         |    59,768,832 |  57 MiB |            14 |    664 |    10 |          45 s |
| `pi0-pgp`      |   235,929,600 | 225 MiB |            62 | 12,012 |    28 |         238 s |

* **Image:** `wc -c image/<profile>.img`. The image is sized to its contents (`mkfs.btrfs
  --shrink`), and for the Pi it includes the 35 MiB boot partition.
* **SBOM packages:** the packages of `image/<profile>.spdx.json`, minus the one that describes the
  image itself:
  `python3 -c 'import json,sys; print(len(json.load(open(sys.argv[1]))["packages"]) - 1)' image/virt.spdx.json`.
* **Files:** the lines of `image/<profile>.root.txt`, which counts directories and links as files.
* **Tests:** `ls profile/<profile>/test | wc -l`. All passed in a run of `check/test <profile>`,
  which boots the image through a temporary overlay, with `TMPDIR` under `$TMPDIR/claude/appeal/`.
  The run was on an aarch64 Mac: `virt` used HVF, and `pi0-pgp` ran in QEMU's emulation of the
  Zero. The `virt` transcript in section 1 is that run's output, unedited. The suite times are wall
  time for `virt`, and the sum of the per-test times for the others.
* **Framework size:** `cat lfs lib/*.sh | grep -cvE '^\s*(#|$)'` gives 1,176 lines, the same on
  `main` and on `docs`. Recipes: `ls package/*.sh package/python/*.sh | wc -l` gives 101.
* **Not measured:** the time of a cold build. The build skill only says "over half an hour" for a
  cold system, which is too vague to print.
