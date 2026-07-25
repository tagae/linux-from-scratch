Build phases and environments
=============================

Three phases (`LFS_PHASE`), each a different executor honoring the same
`/mnt/lfs` project contract and the same `lfs`/`lib/`/`package/` code.

bootstrap (Debian container)
----------------------------

Seeds everything: builds the cross toolchains (binutils/gcc pass 1 and
2 per target triple) plus the build-host-native tool set into the
`tools` volume (TOOL_DIR), using Debian's compiler only as the initial
seed. PATH keeps host tools first, toolchain `usr/bin` last — once
glibc-linked binaries exist they must not shadow host tools mid-phase.
Also generates the from-scratch CA bundle and stages it to
`work/certs/` for the next phase (trust.md).

scratch (FROM scratch container)
--------------------------------

The self-contained build environment: PATH is TOOL_DIR only; no host
userland at all. Because the container's real `/` is empty, the tools
volume's `usr/lib` and `usr/bin` are also bind-mounted read-only at
`/lib`, `/usr/lib`, `/usr/bin` — native codegen helpers that packages
compile-and-run mid-build (and `#!/usr/bin/env` shebangs) resolve
without baking anything into the image. Cross-compiles all target
systems (system phase) and builds images.

Volume/bind split (docker-compose): small, host-shared things are bind
mounts (`lfs`, `lib/`, `package/`, `download/`, `image/`, `archive/`,
`work/boot/`); I/O-hot build state lives in named volumes (`source`,
`work`, `tools`, `install`). `work/boot` is bind-mounted because
host-side `./lfs qemu` must read kernels; named volumes are invisible
outside Docker.

guest (the booted LFS system itself)
------------------------------------

`LFS_PHASE=guest` runs the same machinery natively on a booted target
(self-hosting.md): PATH untouched (the system's own /usr/bin is the
toolchain), heavy dirs guest-local under `/var/lfs`
(SOURCE/WORK/ARCHIVE/INSTALL/IMAGE — compiling over 9p is too slow),
`DOWNLOAD_DIR` stays on the 9p-mounted project (the shared,
hash-verified cache; fully-populated = offline builds).

Cross-phase invariants
----------------------

* `SSL_CERT_FILE`: bootstrap uses Debian's bundle; scratch uses OUR
  generated bundle staged at `work/certs/`; guest uses the system's own
  `/etc/ssl/certs/ca-certificates.crt` (installed by the
  ca-certificates package). Downloads never skip verification.
* Env-overridable dirs (`SOURCE_DIR`, `WORK_DIR`, …) are what let one
  script serve all three executors without code changes.
* QEMU runs on the HOST (not in a container): `./lfs qemu` reads the
  kernel from `work/boot/$SYSTEM_KEY/` and the image from `image/`.
  `QEMU_EXTRA` appends last (overrides -smp/-m); `IMAGE_SIZE` sizes
  built images.
