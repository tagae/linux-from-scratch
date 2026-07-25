Binary packaging: stage → archive → merge
=========================================

Target-scenario packages DESTDIR-install into a per-package staging dir,
get tarred into `archive/$SYSTEM_KEY/<name>-<variant>-<version>.tar.xz`,
and the merged system tree is produced by EXTRACTING the tarball —
so every build continuously proves its own archive is complete.
Tools-phase installs are untouched (they preset `package_install_dir`
and never set `package_merge_dir`).

Properties
----------

* Tarballs are FHS-rooted (`./usr/bin/...`) — packages build with
  `prefix=/usr` — so extracting at `/` on a running system installs to
  standard locations, like a .deb data.tar. Created with
  `--owner=0 --group=0 --numeric-owner`: root extraction yields
  root-owned files.
* `archive/$SYSTEM_KEY/ORDER` records merge order — extraction order
  matters for deliberately-overlapping files (busybox's applet symlinks
  vs util-linux/systemd real binaries). Guests replay ORDER to
  self-install (self-hosting.md).
* `./lfs unarchive FILE [DEST]`; DEST never defaults to `/` (build
  containers bind-mount the toolchain read-only at /usr/{bin,lib}) — a
  live guest passes `/` explicitly.
* The guest phase archives too when GNU tar+xz are present, with a
  plain-tar pipe-copy fallback for a tool-less guest.
* Merge is additive-only: a package CANNOT delete what an earlier
  package merged. Anything subtractive (e.g. skipping a systemd unit
  mask) must be conditional at the source package, not "reversed" by a
  later one (see capabilities.md).

Acceptance (re-provable)
------------------------

The gold round trip: wipe the merged tree, reconstruct purely by
extracting every tarball in ORDER, image, boot. Verified byte-identical
(0 diffs) on virt; pi0 (libtool-relink canary) and busybox flavors boot
the same way; the pi0 self-host capstone repeated it with the payload
baked inside an image, extracted in-guest with no host help.

Gotchas (all hit in practice)
-----------------------------

* Clearing a package's work-dir stamps does NOT force a re-archive if
  its tarball exists (`default_archive` is idempotent) — clear the
  tarball + its ORDER line together, and verify tarball CONTENTS: a
  stale stamp once shipped an empty 160-byte tarball that "succeeded".
* DESTDIR is install-time, so prepare/build stamps survive packaging
  changes — except util-linux, whose generated libtool script bakes CC
  at configure time.
* busybox's install and the kernel's `modules_install` assume merged-usr
  symlinks exist — their scripts pre-create them in the stage dir.
* Merge chmods only the paths its tarball contains (a blanket recursive
  chmod of the merge dir would walk `/` in guest phase).
* Stage dirs are REUSED across install re-runs, never wiped: after
  changing what a script's install() emits, clearing its stamps is not
  enough — files staged by the previous run persist and get re-archived
  (a conditional that now SKIPS creating a file cannot remove the copy
  the old run left). Wipe the package's `install/` stage dir too.
* Deliberately absent: per-dir checksum manifests, archive-all verbs,
  dependency metadata beyond ORDER — "simple tarballs" is the goal.
