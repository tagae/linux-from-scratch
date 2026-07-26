Build environments: one path, detected
======================================

There is no phase flag. `./lfs` computes ONE layout everywhere: code at
$PROJECT_DIR (bind mount in the containers, 9p share on a booted guest,
the repo itself on the dev host), heavy build state under /var/lfs
(named volumes in the containers, local disk on a guest), and the
hash-verified download/ mirror always PROJECT_DIR-relative. Two
detections replace the old bootstrap/scratch/guest LFS_PHASE variable:

* **`[ -d /var/lfs ]`** (lfs) — mounted build state present? If not,
  this is the development host, whose only role is booting the
  bind-mounted artifacts (image/, work/boot/); state dirs then default
  PROJECT_DIR-relative.
* **`_os_is_build_host`** (lib/base.sh) — is the running OS itself an
  LFS build host (a booted guest)? True when `gcc -dumpmachine` carries
  our `-scratch-` vendor triple AND the compiler is not the tools volume
  aliased at /usr (there, $TOOL_DIR/usr/bin/gcc is the same file). Skips
  the build-host construction + tool set (`_bootstrap_build_host`,
  `build_tools`, scratch staging) that a booted LFS already carries, and
  selects the live-`/` install scenario for self-arch one-offs.

Everything else was already detection or is now uniform: kernel headers
and the install scenario key on the per-target sysroot's existence,
archive/merge on `_guest_has_archive_tools`, imaging on kpartx-vs-losetup,
and gcc ALWAYS gets prebuilt gmp/mpfr/mpc (one code path; gcc.sh's
prepare() reconciles the bundled symlinks per build).

The residual seed: `Dockerfile.bootstrap` (Debian) is the only place
with no LFS lineage — there `_os_is_build_host` is false and nothing
exists yet, so `./lfs tools bootstrap` builds the full native build-host
environment before the cross-toolchain. Docker is bootstrap-only; any
booted LFS builds any other LFS (docs/design/guest-cross-builder.md).

The SSL trust anchor is the system path /etc/ssl/certs/ca-certificates.crt
everywhere: Debian ships one, a booted LFS ships its own from-scratch
bundle, and the scratch container gets the bundle bootstrap staged into
the work volume, mounted read-only at that same path (docker-compose).
