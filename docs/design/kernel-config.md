Kernel configuration
====================

QEMU-tested platforms build a minimal kernel from `allnoconfig` plus
composed fragments, NOT the vendor defconfig (which is slow under TCG,
has livelocked, and puts the login on the framebuffer instead of the
serial console). Platforms without a machine config fall back to their
defconfig.

Fragment composition
--------------------

`package/linux.sh` concatenates, in order:

    base.config  $PLATFORM.config  $ARCH.config  $USERLAND.config  <cap>.config...

into `combined.config`, applied via `KCONFIG_ALLCONFIG=... allnoconfig`
then `olddefconfig`. Each platform fragment is self-contained (no
shared "pi" layer). `base` carries btrfs (=y, the root fs) and
devtmpfs; `$USERLAND` carries what the flavor's PID 1 needs; capability
fragments are opt-in (capabilities.md). CAPS is pre-sorted, so the
assembled config — and the kernel — is deterministic per SYSTEM_KEY.

THE trap: allnoconfig force-disables defaults
---------------------------------------------

`allnoconfig` zeroes every option, including `default y` ones AND the
menu/gating parents whole subsystems hide behind (`if USB_SUPPORT`
blocks etc.). A fragment listing only the leaf option silently produces
a config WITHOUT it — sometimes without even an "is not set" line.
Documented instances: `COMPAT_32BIT_TIME` (glibc abort in PID 1),
`NETDEVICES`/`NET_CORE` (virtio-net invisible, guest had only `lo`),
`NETWORK_FILESYSTEMS` (9p), `USB_SUPPORT`/`USB_PCI` (xhci never bound).
Rule: after any fragment change, verify the option in the RESOLVED
`.config`, never trust the fragment.

Kernel sources are pinned to immutable release tags
---------------------------------------------------

virt/headers use kernel.org release tarballs; Pi platforms pin
raspberrypi/linux `stable_YYYYMMDD` TAGS (all Pi platforms share one
tag). Never branch archives: a branch head moves, so its tarball's
bytes change under the sha256 pin (happened in practice; the pin
correctly rejected it). Historical note: pi0 briefly needed a 6.6-line
pin for a bcm2835-sdhost DMA regression (raspberrypi/linux#7136); the
pin is retired because pi0.config drops CONFIG_DMADEVICES (for QEMU's
own incomplete SD-DMA emulation), which also sidesteps the regressed
path — re-check #7136 if DMADEVICES is ever re-enabled.

Other per-platform notes
------------------------

* virt carries an RTC (PL031 + HCTOSYS) — without it the guest clock
  boots at build-epoch and TLS certificate validation fails. Real Pis
  have no RTC; air-gapped appliances must set the clock manually
  (gnupg-appliance.md).
* Changing fragment content does NOT invalidate kernel stamps (they
  key on name/version) — wipe the affected `work/linux-<key>-*` build
  dirs to force a re-prepare.
