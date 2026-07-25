The amnesia capability: a boot medium that is never written
===========================================================

`CAPS=amnesia` makes a built system run from a genuinely read-only
root: nothing persists across boots, and the boot medium (SD card,
image file) provably leaves every session exactly as it was flashed —
the property that makes an air-gapped appliance's card trustworthy and
discardable (gnupg-appliance.md).

Design: read-only root + targeted tmpfs — no overlay, no initrd
---------------------------------------------------------------

Three designs were considered. `systemd.volatile=overlay` is
implemented by a service that only runs in an initrd — this project
boots kernels directly and has none. A hand-rolled overlayfs initramfs
would work but adds a whole new boot stage. The chosen design needs
neither: mount `/` read-only and give the few paths that genuinely need
writing a RAM answer:

* `/run` — systemd always mounts this tmpfs itself (and the appliance
  workflow keeps GNUPGHOME here, so keys live only in RAM).
* `/var`, `/tmp`, `/root` — tmpfs via fstab entries shipped by
  `package/amnesia-config.sh`; systemd-tmpfiles recreates the /var
  skeleton each boot (journald logs volatile to /run).
* `/etc/machine-id` — shipped EMPTY; systemd on a ro root then
  generates a transient ID per boot (manifests as a small tmpfs mounted
  directly on the file; a different random ID every boot).
* `/mnt/usb` — shipped as a directory: `mkdir` fails on a ro root, but
  `mkdir -p` of an existing dir succeeds, so USB mounting keeps working.

The cmdline (QEMU append and the Pi's cmdline.txt) becomes `ro` with
`rootflags=...,rescue=nologreplay` — the rescue= spelling is required
on modern kernels (bare `nologreplay` panics); nologreplay matters
because even btrfs log-tree replay is a device write.

Per-flavor mechanics
--------------------

* systemd: the tmp.mount mask in systemd.sh is skipped when CAPS
  contains amnesia — a masked unit outranks the fstab generator, and
  merge being additive-only means a later package cannot remove the
  mask (capabilities.md's conditional-at-the-source rule; this is the
  case that discovered it). Zero failed units on a ro root.
* busybox: an /etc/init.d drop-in runs `mount -a` and recreates the
  few /var/log files login/getty expect (wtmp, btmp, lastlog, faillog).

The proof
---------

Because writes never happen (rather than being discarded, as an overlay
would), the verification is absolute: the image file's SHA-256 is
byte-identical before and after full boot → keygen-to-USB → poweroff
cycles, across both init flavors. Any future regression that writes to
the boot medium fails this check loudly.

Trade-offs and limits
---------------------

* The root *feels* read-only (`touch /x` fails) rather than
  transparently writable — for an appliance that's a feature; the
  overlay design remains possible later if the illusion is ever wanted.
* microSD has no physical write-protect switch — read-only is enforced
  by the kernel mount, which is also what the hash proof verifies.
* A cosmetic systemd-tmpfiles no-op (wtmp/lastlog `f`-type lines) traces
  to the merged tree's build-uid ownership of `/`, a pre-existing
  image-build gap unrelated to amnesia (packaging.md gotchas).
