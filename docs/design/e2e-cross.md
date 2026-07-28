End-to-end self-host: guest builds a pi0 GnuPG appliance
========================================================

`make e2e-test` proves the strongest self-hosting claim: from a pristine
state, the Debian bootstrap builds the virt tools; a virt guest boots and
builds ITS OWN aarch64→arm cross-toolchain natively; the guest then
cross-compiles a complete pi0 image including the GnuPG family; and the
host boots that pi0 image and generates a keypair with separate
encryption and authentication subkeys. Runtime is measured in hours by
design (the guest cross-builds a full toolchain + system under emulation).

This is distinct from the self-hosting.md milestones: those had the guest
build NATIVELY for its own arch (virt→virt), and delivered pi0 artifacts
CROSS-built in the container. Here the guest itself is the cross-build
host for a foreign arch — a capability the container previously had a
monopoly on.

Stages (each independently verifiable)
--------------------------------------

**E1 — the builder guest.** A `systemd-busybox-virt+9p+loop` systemd image carrying the
native toolchain (native-toolchain) + the full build tool set
(bison/flex/bc/gperf/pkgconf/gettext/m4/tar/xz/python/meson/ninja/perl +
gawk/coreutils/bash/patch/kmod). Reuses the self-hosting.md M1–M3
delivery. Boot it with QEMU_EXTRA="-smp N -m NNNN" and a large
IMAGE_SIZE. Acceptance: in-guest `gcc`, `make`, `bison`, `python3` all
run.

**E2 — guest-phase cross-toolchain (`LFS_PHASE=guest ./lfs tools` for a
foreign PLATFORM).** The new capability. `lib/tools.sh`'s bootstrap_tools/
build_tools already build a cross-toolchain (binutils/gcc/glibc, host=the
build machine, target=$target); today they run only in the Debian/scratch
containers. Guest-phase changes needed:
  - Run without docker: the guest invokes `LFS_PHASE=guest PLATFORM=pi0
    ./lfs tools bootstrap && ./lfs tools build` directly.
  - native_target = the GUEST's own gcc (its native toolchain from E1)
    rather than Debian's — the "generation N builds N+1" seed is now the
    guest's compiler.
  - TOOL_DIR guest-local (/var/lfs/tools), PATH assembled from it.
  - The from-scratch CA chain / anything container-specific
    (docker-compose read-only /lib mounts, work/scratch-init) must be
    guarded off in guest phase.
  Acceptance: `install/…/…-arm-…-gcc` etc. built in the guest, EM_ARM
  cross-compiler that runs on aarch64 and emits arm.

**E3 — guest cross-compiles the pi0 GnuPG system + image.** With the arm
cross-toolchain on the guest's PATH, `LFS_PHASE=guest PLATFORM=pi0 ./lfs
system build` (bootable-systemd-busybox) then `install` the gnupg family, then
`./lfs image build`. The kpartx→losetup fallback (self-hosting.md M4) and
loop capability already handle in-guest imaging. The pi0 image is copied
out over 9p to the host image/ dir.

**E4 — verify on pi0.** Host boots the guest-built pi0 image. Generate a
keypair whose structure is: primary (cert), an ENCRYPTION subkey, and an
AUTHENTICATION subkey (`--quick-generate-key` gives primary + encr;
`--quick-add-key <fpr> <algo> auth` adds the auth subkey). Assert
`gpg --list-keys --with-subkey-fingerprint` (or --with-colons) shows a
subkey with capability `e` and one with capability `a`. Avoid the
serial-console sign hang documented in gnupg-keygen.sh — this is
keygen + subkey structure, no detached-sign needed.

Automation (`make e2e-test`)
----------------------------

`make e2e-test` runs `tests/e2e/run.sh`, which orchestrates:

* **`tests/e2e/e1-builder-image.sh`** — runs only when `image/systemd-busybox-virt+9p+loop.
  img` is absent (pristine state): container-side, it builds the tools
  (Debian bootstrap + scratch), the builder system (`CAPS="9p loop"`),
  bakes the full build tool payload into the image tree as ordinary target
  packages (zlib/libffi, native-toolchain, the M3 tool set, python+
  markupsafe/jinja2/meson/ninja, btrfs-progs/dosfstools), runs the
  container pi0 baseline (system + GnuPG family — this populates the
  `download/` source mirror the NO-NETWORK guest builds from), and builds
  the 64g builder image. Against a warm builder image this is skipped.
* **`tests/e2e/builder.exp`** — boots the `systemd-busybox-virt+9p+loop` builder guest
  (`QEMU_EXTRA="-smp 8 -m 8192"`, HVF) and runs the in-guest build to a
  sentinel.
* **`tests/e2e/guest-build.sh`** — runs INSIDE the guest (POSIX sh): the E2
  cross-toolchain (`LFS_PHASE=guest PLATFORM=pi0 ./lfs tools bootstrap`),
  the E3 system + GnuPG family + image, then copies `pi0.img` + kernel/dtb
  out over 9p to `image/e2e-pi0.img` and the canonical `work/boot/systemd-busybox-pi0/`
  (the guest-built kernel supersedes any container baseline's). It first
  applies the **builder-guest tool completions** — overlaying the correct
  target-built zlib/python(with-zlib)/kmod/btrfs-progs archives onto the
  live `/` and a native `dosfstools` — that the base image's tools lack for
  cross-building a foreign-arch image. Idempotent, so it fast-paths every
  already-built package against a warm builder guest.
* **`tests/e2e/keygen.exp`** — boots the guest-built pi0 image on the host
  (TCG, default `WORK_DIR`) and asserts a keypair with a `cv25519`
  encryption subkey (cap `e`) AND an `ed25519` authentication subkey
  (cap `a`) via `--with-colons`.

Expect gotchas baked into the drivers: login is matched with the glob
`"login:"` (an anchored regex fails — agetty appends a terminal-query
escape); the keygen is one compound command ending in a `''`-split sentinel
matched in OUTPUT, so no post-command prompt matching (bash bracketed-paste
`\e[?2004h` after `# ` breaks that).

The in-guest completions in `guest-build.sh` are probe-first: a fresh E1
image bakes them all in (probes pass, nothing runs); an older or hand-grown
builder image gets each missing capability overlaid from the target-built
virt archives on the 9p share. `download/` is kept across `make distclean`
as the hash-pinned source mirror by design — if it was wiped anyway, E1's
container pi0 baseline repopulates every source the guest needs (the guest
has no network: CAPS is `9p loop` only).

Open risks
----------

- Guest RAM/disk for cross-building glibc+gcc under emulation (E2 is the
  heaviest); size the builder image and QEMU_EXTRA generously.
- tools.sh assumes a lot of container context; the guest-phase guarding
  (E2) is the real engineering, and where surprises will surface.
- Wall-clock: a full cross-toolchain + pi0 system build under HVF is
  long but bounded; TCG would be impractical — the BUILD runs on the
  aarch64 guest (HVF), only the final pi0 image BOOT (E4) is TCG.
