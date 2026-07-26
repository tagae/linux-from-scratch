TODO: eliminate LFS_PHASE
=========================

Goal (per the "guest as universal builder" guideline): make running on a
booted LFS the default, with Docker as bootstrap-only. `LFS_PHASE`
(bootstrap|scratch|guest) bundles three unrelated distinctions into one
mode string; most should be *environment detection* (the model already
used for kpartx-vs-losetup in lib/image.sh and `_guest_has_archive_tools`
in lib/package.sh), not a phase branch. Do this AFTER the e2e capability
(E2/E3, docs/design/{guest-cross-builder,e2e-cross}.md) lands — it's
cleanup, not capability, and E2/E3 are actively mapping which
guest-vs-container differences are essential vs incidental.

The five mappings (each removes a use of LFS_PHASE)
--------------------------------------------------

1. **Base dir → /var/lfs everywhere.** Split PROJECT_DIR (the code:
   lfs/lib/package/download) from build STATE (source/work/tools/install/
   image/archive). Default build-state to `/var/lfs/*` ALWAYS, and
   `DOWNLOAD_DIR=$PROJECT_DIR/download` ALWAYS. Then docker-compose mounts
   its volumes at `/var/lfs/*` (not `/mnt/lfs/*`); the guest keeps them
   local at `/var/lfs/*`. Container and guest then compute identical
   paths — bind/volume vs 9p/local is a mount concern invisible to the
   code. Removes the LFS_PHASE dir block in `lfs`.

2. **PATH → `$TOOL_DIR/bin:/usr/bin:/usr/sbin` everywhere.** The scratch
   container ALREADY mounts `TOOL_DIR/usr/bin` at `/usr/bin` (see
   docker-compose.yaml), so this resolves in both: cross-tools from
   `TOOL_DIR/bin`, system tools from `/usr/bin`. Removes the scratch/guest
   PATH branch.

3. **SSL_CERT_FILE → the system path everywhere.** Use
   `/etc/ssl/certs/ca-certificates.crt` in both; have the scratch
   container additionally mount `TOOL_DIR/etc/ssl` (it already mounts
   `TOOL_DIR/usr/{bin,lib}`). Removes the SSL_CERT_FILE branch in `lfs`.

4. **Build-host-env construction → detection.** Replace the E2 guard
   (`[ LFS_PHASE = guest ]` skips the native toolchain + tool set +
   temp-tools + CA blocks in lib/tools.sh's bootstrap_tools) with a
   detection of whether a usable native toolchain + tool set already
   exist. If yes (a booted LFS, or a warm container), build only the
   cross-toolchain; if no (fresh Debian), build everything. Strictly more
   robust than the phase check; drops the guard.

5. **guest_build_env (merge into `/`) → a destination, not a phase.**
   "Install into the running system" is just `-d /`; "build a target
   tree" is the default (target_build_env). The `-d DESTINATION`
   mechanism already exists (lib/package.sh install()), so
   guest_build_env collapses into "destination is `/`". Removes the
   guest-vs-target env fork.

Residual (genuinely distinct — keep, but not as a 3-way LFS_PHASE)
-----------------------------------------------------------------

The Debian bootstrap SEED (Debian's gcc + host PATH + no toolchain yet)
must stay distinct — but that is the accepted Docker bootstrapping role.
Make it a dedicated entry point / detected condition ("no toolchain
exists yet → seed one"), not a general phase flag. With #4 as detection,
a single `./lfs tools` does the right thing everywhere: bootstrap detects
nothing → builds the full native env + cross-toolchain; a guest detects
its own → builds only the cross-toolchain. bootstrap/scratch/guest
converge on one code path parameterized by what exists.

Touch list (for the eventual pass)
----------------------------------
`lfs` (dir defaults, PATH block, SSL_CERT_FILE block, drop the LFS_PHASE
branches); `docker-compose.yaml` (volume mount points → /var/lfs; add a
`TOOL_DIR/etc/ssl` mount); `lib/tools.sh` (detection instead of the E2
guard); `lib/package.sh` (guest_build_env → destination); `lib/image.sh`
already env-detected (kpartx/losetup) — the model to follow.
