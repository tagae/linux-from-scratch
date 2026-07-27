Userland flavors and capabilities
=================================

Two orthogonal axes select what a built system contains, both folded
into `SYSTEM_KEY` so every combination gets its own install tree,
stamps, boot files and image, coexisting without clobbering.

USERLAND flavor
---------------

`USERLAND` (default `systemd-busybox`; also `systemd-coreutils`,
`busybox`) names the complete userspace composition — the init system
included, since PID 1 is itself a userland program. It selects the
umbrella (`bootable-$USERLAND`) and hence the whole member set, the
per-flavor system-files content, and the per-flavor kernel fragment
(`package/linux/$USERLAND.config` — busybox's PID 1 needs none of
systemd's cgroups/namespaces/BPF, ~23% smaller kernels). Key: always
`$USERLAND-$PLATFORM`. The busybox flavor is static — no glibc — so
dynamically-linked optional packages (gnupg, native toolchain) require
a glibc flavor (`systemd-busybox`/`systemd-coreutils`).

CAPS capabilities
-----------------

`CAPS` is a space-separated opt-in list (e.g. `CAPS="9p network"`).
Each capability `<cap>` is:

* a kernel fragment `package/linux/<cap>.config` (its existence
  validates the name; comment-only fragments are legal),
* optionally a `<cap>-config` package the umbrellas `require`
  conditionally (`case " ${CAPS:-} " in *" <cap> "*)`),
* optionally QEMU flags appended in `lfs`'s qemu case.

CAPS is sorted/deduplicated, then folded: `virt+9p+network`. The empty
default leaves SYSTEM_KEY — and every pre-existing build — untouched;
that byte-identity is a hard invariant (the project's network-less
Pi Zero depends on it).

Current capabilities: `network` (IP stack + virtio-net; networkd DHCP,
resolved with DNS-from-DHCP and mDNS/.local on all interfaces),
`9p` (project share at /mnt/lfs), `usb` (host stack + mass-storage +
vfat; xhci for virt, dwc2 for Pi), `loop` (loop devices, for in-guest
image building), `amnesia` (read-only root; see amnesia.md).

Design rules learned the hard way
---------------------------------

* **Subtractive changes must be conditional at the source package.**
  Merge is additive-only (packaging.md): a capability package cannot
  delete a mask an earlier package merged. E.g. systemd.sh itself skips
  the tmp.mount mask when CAPS contains amnesia. An `rm` of another
  package's file in a capability package's own stage dir is a silent
  no-op. Both known cases (tmp.mount for amnesia, the networkd masks
  for network) are gated in systemd.sh accordingly.
* Capability packages that reverse systemd masking must be ordered
  after systemd in the umbrella; ones dropping /etc/init.d scripts
  after busybox-init.
* Kernel fragments must be verified against the RESOLVED .config
  (kernel-config.md — the menu-gating trap).
* QEMU capability flags are conditional on both the cap and any needed
  env (e.g. usb needs `USB_DISK=<file>`); pi machines have no virtio or
  PCI, so virtio/xhci-based wiring is virt-only.
