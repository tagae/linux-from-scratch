The guest as a universal builder
================================

Guiding principle: Docker is a bootstrap mechanism only —
`Dockerfile.bootstrap` seeds a cross-toolchain from Debian, and
`Dockerfile.scratch` shows a minimal `FROM scratch` base building LFS
itself. Once ANY LFS guest exists (any platform/arch), that guest should
be able to build ANY other LFS — any architecture, init flavor, and CAPS
combination — including, as a particular case, building packages for
itself. This document is the capability that makes "an LFS guest
cross-builds a foreign-arch LFS" true (deviations #1/#2 in the design
review); it is proven by `make e2e-test` (docs/design/e2e-cross.md).

The key realization
-------------------

`lib/tools.sh`'s `bootstrap_tools()`/`build_tools()` do TWO things:

1. **Construct the build-host environment** — the native (build-host
   arch) pass1-native toolchain, native glibc, the entire temp-tools
   userspace (bash/coreutils/sed/tar/make/...), the CA trust chain,
   rpath relocation (`_tools_relocate`/`_tools_set_rtld_ldflags`), and
   the `SCRATCH_INIT_DIR`/`work/certs` staging Docker needs. This is what
   turns an empty Debian/scratch container into a usable build host.

2. **Build the TARGET cross-toolchain** — pass1 (throwaway, targets
   $target, builds the sysroot glibc), the per-target sysroot
   (linux#headers + glibc), and pass2 (the real, shipped $target cross-
   compiler).

**In a booted LFS guest, (1) already exists** — the guest IS a full LFS
system: it has a native gcc (native-toolchain), the whole tool set
(bison/flex/perl/python/make/...), a real `/usr/lib` on the runtime
loader path (so no rpath relocation), and a system CA store. So guest-
phase `./lfs tools` runs ONLY part (2), seeded by the guest's own gcc
instead of Debian's. This is the "generation N builds generation N+1"
lineage applied to the cross-toolchain itself.

Changes
-------

**A. Guest-phase `./lfs tools` (lib/tools.sh).** `bootstrap_tools()`
skips the part-(1) blocks when `LFS_PHASE=guest` and keeps the part-(2)
cross-toolchain blocks:
  - SKIP: pass1-native, the native runtime glibc, the bare-name toolchain
    symlinks, the libstdc++/libgcc_s staging, the temp-tools subshell,
    the CA chain, `_tools_set_rtld_ldflags`, `_tools_relocate` (patchelf
    is container-only), and the `work/certs`/`SCRATCH_INIT_DIR` staging.
  - KEEP: pass1 cross, per-target sysroot (linux#headers + glibc), pass2
    cross. These build with bare `gcc` = the guest's own native compiler.
  - `native_target`: still derived from `uname -m` (the guest reports its
    own arch); used only where a build-host triple is needed.
  - `build_tools()` is SKIPPED entirely in guest phase — its output
    (bison/flex/perl/kmod/util-linux/btrfs-progs/kpartx/...) is exactly
    the tool set the guest already carries.
  - TOOL_DIR is guest-local (`/var/lfs/tools`, per lfs's guest-phase dir
    defaults); the cross-compiler lands at `/var/lfs/tools/bin/$target-*`.
  - No rpath juggling: pass2 gcc is a native (guest-arch) binary that
    finds libstdc++/libgcc_s on the guest's ordinary `/usr/lib` loader
    path.

**B. Guest cross-build (lib/package.sh + lib/system.sh).** Building a
system for a FOREIGN platform in the guest must cross-compile, not build
natively:
  - When guest-phase `system build`/`install` targets a platform whose
    `$target` differs from the guest's own arch, set `host=$target` (so
    packages configure as a cross build) and ensure `$target-gcc` (the
    guest-built cross-toolchain) is used — i.e. the guest's
    `target_build_env` path, but with the cross-toolchain from
    `/var/lfs/tools`. When the target IS the guest's own arch, the
    existing native path stands (that is the "guest builds for itself"
    case, already working).
  - `target_sysroot_cc` and the sysroot flags already point at
    `$INSTALL_DIR/$SYSTEM_KEY`; guest-local `$INSTALL_DIR` (`/var/lfs/
    install`) makes this work unchanged.

**C. PATH (lfs).** Guest phase currently leaves PATH untouched. It must
additionally put `$TOOL_DIR/bin` (=`/var/lfs/tools/bin`) on PATH so the
just-built `$target-*` cross-tools are found by `system build` — without
shadowing the guest's own `/usr/bin` (append, don't prepend the parts
that would mask native tools; the cross-tools are `$target-`prefixed so
they never collide with bare names anyway).

What e2e-test exercises
-----------------------

`make e2e-test`, from pristine: Debian bootstrap → virt tools → boot the
builder guest → in-guest `LFS_PHASE=guest PLATFORM=pi0 ./lfs tools
bootstrap` (builds the arm cross-toolchain via A) → `system build` +
GnuPG + `image build` for pi0 (via B) → copy the pi0 image out → host
boots it → keypair with encryption + authentication subkeys.

Deferred (not needed for this capability)
-----------------------------------------

Full phase unification — collapsing the `LFS_PHASE=scratch` vs `guest`
forks into one build-host abstraction so the guest becomes the DEFAULT
builder and the scratch container the exception (design-review deviation
#4) — is a larger refactor worth its own pass. This capability delivers
the load-bearing "any LFS builds any other LFS" without it.
