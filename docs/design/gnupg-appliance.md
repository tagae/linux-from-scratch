GnuPG and the air-gapped key appliance
======================================

The end goal: a Pi Zero as an air-gapped keypair-generation appliance —
keys are born in RAM, leave only on removable USB (passphrase-protected
secret + public + revocation certificate), and the boot SD is
discardable because it is provably never written.

The GnuPG family
----------------

Optional packages (never in an umbrella), BLFS-2.5.17-aligned, built
per SYSTEM_KEY as archive tarballs. Install order (ad hoc, nothing
enforces it):

    zlib → libgpg-error → npth → libassuan → libksba → libgcrypt →
    libusb → gnupg → pinentry
    (+ gmp → nettle → libtasn1 → gnutls before gnupg, only for
       dirmngr/keyserver support)

gnupg builds WITHOUT a TLS backend (configure skips dirmngr); with the
gnutls chain, dirmngr + hkps keyservers work — proven end-to-end
against keys.openpgp.org through the project's own CA store (trust.md)
on a network-capability guest. Keygen note: this build rejects
`default` as `--quick-generate-key`'s expire argument — use `0`.

Smartcards (YubiKey) need no kernel driver: scdaemon is built with its
integrated CCID driver linking libusb (verified in the ELF) and talks
raw USB via /dev/bus/usb — no pcscd/libccid. `gpg-card` ships.

The appliance
-------------

* **`gpg-genkey`** (package + /usr/bin script; pulls the keygen family
  via depends): GNUPGHOME on a /run tmpfs (RAM only), mounts the USB
  stick, generates (batch + loopback pinentry), exports
  `<email>-{secret,public,revoke}.asc`, unmounts, wipes. Proven on
  virt including a fresh-boot re-import of the exported key.
* **`usb` capability**: USB host + mass-storage + vfat (xhci for virt,
  dwc2 for the Pi's OTG port). QEMU attaches a stick when
  `USB_DISK=<file>` is set.
* **`amnesia` capability**: read-only, never-written boot medium —
  design, mechanics and the SHA-256 byte-identity proof in amnesia.md.
* Keygen entropy is a non-issue even air-gapped: modern kernels
  jitter-seed the CRNG in seconds with no hardware RNG (verified,
  `crng init done` ~7 s on emulated pi0; keys are cryptographically
  sound, no shortcuts).

Remaining (hardware-dependent)
------------------------------

1. pi0 appliance image with `CAPS="usb amnesia"` + family + gpg-genkey;
   in QEMU verify as far as raspi0's dwc2 emulation allows (scdaemon
   starts; `gpg --card-status` reports "no card", not a missing
   mechanism).
2. Real-hardware boot: `package/firmware.sh` exists but nothing
   installs it yet; boot.sh's cmdline/config are pi0-correct.
3. The card-present path (`keytocard` to a physical YubiKey on the OTG
   port): not reliably testable from a macOS host (CryptoTokenKit
   claims CCID devices; usb-ccid passthru needs a Linux pcscd) — real
   hardware is the authoritative test. No-RTC means the operator should
   set the clock before generating (key creation timestamps).
