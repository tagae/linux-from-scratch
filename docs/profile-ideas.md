Profile Ideas
=============

Profiles that would suit this project, ranked, with what each would cost. They are based on the
tree and on upstream sources as of 2026-11-26 (see [Sources](#sources)). Where a fact could not be
confirmed, the text says so.

The ideas build on what the project does well: a single-purpose Pi Zero that is on no network,
whose read-only root keeps nothing across boots ([pi0-pgp](../profile/pi0-pgp.md)), with secrets
only in memory that does not swap and is zeroed when freed. Programs come from upstream and run as
shipped. Everything is built from source and has an SBOM, and is tested under QEMU, with emulated
USB sticks and a CCID reader.


Ranked Ideas
------------

### 1. `pi0-ca`: an Offline Certificate Authority

**Purpose.** A root CA that is never online: it signs the CSRs of intermediate CAs and servers
that come in on a USB stick, and issues CRLs, and it is also an SSH certificate authority for user
and host certificates. Who wants it: anyone who runs a private PKI (a homelab, a small company)
with an online intermediate (step-ca, Vault, an ACME server) and wants the root offline, and
anyone who wants SSH certificates in place of `authorized_keys`. Root keys are usually kept on an
air-gapped machine like this.

**Platform.** `pi0`, as it is. The CA signs only a few certificates per ceremony, so the Zero's
speed does not matter.

**Design.** The pattern is that of `pi0-pgp`. The CA key is either made in memory and backed up,
passphrase-protected, to a stick, or made on a YubiKey's PIV application, where it cannot be
exported. The CA's state (`index.txt`, `serial`, `crlnumber`, the issued certificates) lives on the
CA's stick, so the SD card stays read-only. The clock must be set before signing, because
certificates carry their validity dates. Upstream tools are used directly: `openssl req`/`ca`/`crl`
with an `openssl.cnf` of the profile (its policies and extensions are where the real work is), and
`ssh-keygen -s`. Per its manual, `ssh-keygen -s` can use a CA key held in a PKCS#11 token (`-D`)
or in an agent (`-U`).

**Packages that exist.** The base of `pi0-pgp` (systemd, D-Bus, polkit for `poweroff`, util-linux,
coreutils, bash, mandoc, tzdata), `dosfstools`, and `openssl`, this time with its apps
(`disable=legacy`, not `apps legacy`). Also `pcsc-lite`, `ccid` and `libusb` for the PIV reader,
and `zlib`. `libfido2`/`libcbor` are needed only if SSH FIDO keys are wanted. There is no Python or
Rust: the image is far smaller than `pi0-pgp`'s, and builds faster.

**New recipes.**

| Recipe                 | Upstream                       | Version, date      | Size   | Licence       |
|------------------------|--------------------------------|--------------------|--------|---------------|
| `openssh`              | openssh.com, portable          | 10.6p2, 2026-11-05 | 2.3 MB | BSD-style set |
| `pkcs11-provider`      | github.com/openssl-projects    | 1.3.0, 2026-09-22  | 237 kB | Apache-2.0    |
| `yubico-piv-tool`      | developers.yubico.com          | 2.7.3, 2026-01-20  | 2.2 MB | BSD-2-Clause  |
| `opensc` (alternative) | github.com/OpenSC              | 0.27.1, 2026-03-31 | 2.5 MB | LGPL-2.1      |

What is awkward about them:

* `openssh`: the recipe installs `ssh-keygen` and nothing else (plus its PKCS#11 helper, if it uses
  one: not checked). Its `LICENCE` has 8 parts, public-domain code among them, all of which go into
  the SPDX expression, as btrfs-progs' bundled code did. Its configure accepts OpenSSL 4 (`40*`).
* `pkcs11-provider`: Meson, and libcrypto >= 3.0.7. Its CI builds against OpenSSL master, but 4.0.3
  itself is not confirmed.
* `yubico-piv-tool`: CMake. It needs `gengetopt` at build time, a new tools recipe (GNU, 585 kB).
  On Linux, configure requires the `check` test library even when no test runs: one more recipe,
  for the sysroot only. The man page ships prebuilt: `GENERATE_MAN_PAGES=OFF` spares running the
  target's binary under help2man.
* `opensc`: works with any PIV card, not just YubiKeys, and replaces `yubico-piv-tool` with one
  recipe. How it builds its man pages was not checked.

`pkcs11-provider` is how OpenSSL 4 reaches a token: OpenSSL 4.0 removed engines. `libykcs11`
(from `yubico-piv-tool`) or `opensc-pkcs11` is the token's module. Choosing between those two is a
decision for the owner: Yubico's own tool manages a YubiKey fully (management key, attestation),
while OpenSC works with any PIV card.

**Kernel capabilities.** Those of `pi0-pgp` without `ext4`, and without `hidraw` unless SSH FIDO
keys are wanted: `btrfs console fat hardening modules overlay serial-console systemd usb usb-storage
zero-on-free`. No new capability.

**QEMU.** QEMU can test everything but the YubiKey, as for `pi0-pgp`: a CA made in memory, a CSR
from the stick signed, a CRL issued, an SSH certificate made and checked with `ssh-keygen -L`, the
CA's state written to the stick and back after a reboot, and nothing left in memory after it.
`-device usb-ccid` shows that `pcscd` finds the reader, but QEMU's emulated card is no YubiKey PIV
application, so the PKCS#11 signing path can be tried only on the Pi.

**Effort.** Medium. Phase 1 (keys in memory, OpenSSL apps, OpenSSH) is one new recipe, plus the
profile's files (`openssl.cnf`, mount units for the CA stick, a manual page `pi0-ca(7)`) and its
tests. Phase 2 (keys on the YubiKey) adds `pkcs11-provider` and either OpenSC, or
`yubico-piv-tool` with `gengetopt` and `check`. It is a new profile key, so no existing archive is
invalidated.

**Risks, and when it would be a bad idea.**

* X.509 policy is easy to get wrong (path lengths, name constraints, key usages, CRL distribution
  points). The `openssl.cnf` is the product, and it needs tests that check the extensions of what
  it signs.
* A wrong clock produces certificates with wrong dates: whatever does the signing should refuse
  while the clock still shows the image's epoch.
* If the CA stick is lost, the CA's database is lost with it, so the profile has to document a
  second stick.
* OpenSSL 4.0 is not an LTS release (it is supported until May 2027), and the PKCS#11 provider has
  not been confirmed on it. Every profile depends on OpenSSL's release cadence anyway.
* It is a bad idea if the owner wants `pi0-pgp` to be the project's one air-gapped environment. In
  that case it would become a section of `pi0-pgp`, which today says "no X.509" on purpose, and
  whose image is already large.

### 2. `pi0-sheepdip`: a Station for Untrusted USB Media

**Purpose.** It copies files from a stick that is not trusted to a clean one without the kernel
ever mounting the untrusted file system. The file system is read in user space, by a sandboxed
process, and the destination is a fresh file system that the station makes. The computer that
gets the clean stick then parses a file system that `mkfs` made, not the sender's. Who wants it:
journalists and others who are handed sticks, and anyone who feeds files into an air-gapped machine
(`pi0-pgp` included, whose own documentation says to "power the Pi off between such a device and
secrets"). The name is a placeholder: "sheep dip" is the usual term for such a station.

**Prior art.** CIRCLean (CIRCL, BSD-3-Clause) does this and also converts documents. It is a
Raspbian Jessie image, and its master branch was last committed to in February 2020. Whether it
mounts the source stick with the kernel could not be confirmed.

**Platform.** `pi0`: it has a USB host port, no radio, and the test harness already attaches
sticks to it.

**Design.** The untrusted stick's file system is never mounted:

| File system | Read in user space with                  | Recipe                                    |
|-------------|------------------------------------------|-------------------------------------------|
| FAT         | `mcopy -s -i /dev/sdX1 ::/ dest/`        | `mtools` (exists; tools only today)       |
| ext2/3/4    | `debugfs -c -R 'rdump / dest' /dev/sdX1` | `e2fsprogs` (exists)                      |
| BTRFS       | `btrfs restore /dev/sdX1 dest/`          | `btrfs-progs` (exists), with zstd and LZO |

Each reader runs as a transient unit (`systemd-run`) that has the device read-only and nothing
else. The unit has no network, and its file system view, system calls and devices are limited,
which the `systemd` capability already supports. The destination is formatted by the station
(`mkfs.fat`) and mounted by the kernel, and it gets a manifest of SHA-256 sums and file types. The
only home-grown part is a thin profile script, like `gpg-genkey`, that runs these steps.

**Packages that exist.** The `pi0-pgp` base, plus `mtools` for the system (the recipe exists),
`e2fsprogs`, `btrfs-progs`, `dosfstools` and `util-linux` (`sfdisk`, `blkid`), and `coreutils`
(`sha256sum`).

**New recipes.**

| Recipe       | Upstream                   | Version            | Licence               | Phase |
|--------------|----------------------------|--------------------|-----------------------|-------|
| `zstd`       | github.com/facebook/zstd   | not checked        | BSD-3-Clause OR GPL-2 | 1     |
| `lzo`        | oberhumer.com              | 2.10               | GPL-2.0               | 1     |
| `file`       | astron.com                 | 5.48               | BSD-style             | 1     |
| `f3`         | github.com/AltraMayor/f3   | v10.0              | GPL-3.0               | 2     |
| `ntfs-3g`    | github.com/tuxera/ntfs-3g  | 2026.9.28          | GPL-2.0               | 2     |
| `fuse-exfat` | github.com/relan/exfat     | 1.4.0 (2023)       | GPL-2.0               | 2     |

* `zstd` and `lzo`: without them `btrfs-progs` cannot restore compressed files, as
  [pi0-pgp.md](../profile/pi0-pgp.md) says of `btrfs restore`.
* `file`: the file types for the manifest. libmagic also parses hostile input, so it runs in the
  sandbox too.
* `f3`: optional; it finds sticks that fake their capacity. `f3probe` links libudev (systemd's),
  and `f3fix` links libparted, which can be left out.
* `ntfs-3g`: NTFS, read through ntfsprogs or its built-in FUSE.
* `fuse-exfat`: exFAT. It needs libfuse (one more recipe) and a new `fuse` capability.

**Kernel capabilities.** `btrfs` (the root only), `console fat hardening modules overlay
serial-console systemd usb usb-storage zero-on-free`. Leaving out `ext4` and `hidraw` is the point:
the kernel cannot mount the sticks' ext4, and with no HID, a stick that claims to be a keyboard
(BadUSB) types nothing. A real trade-off for the owner: the kernel still parses partition tables
(`usb-storage` turns on MBR and GPT). A variant of the capability without them, together with
`sfdisk` and `losetup --offset` (a new `loop` capability), would move that parsing to user space
too, at the cost of a capability that nearly duplicates `usb-storage`.

**QEMU.** QEMU can test all of it, which is where this idea is strongest. The harness can attach two
`usb-storage` sticks to raspi0. The guest makes an "untrusted" stick of each file system as root,
the station copies it, and the tests check the manifest, that `/proc/mounts` never lists the
source, and that a deliberately corrupted image makes the reader fail inside its sandbox without
hurting the system.

**Effort.** Small to medium: no Python, Rust or GnuPG, and two to three new recipes in phase 1.
Most of the work is the script, its units and the tests.

**Risks, and when it would be a bad idea.**

* It does not disarm content: a malicious PDF arrives as a malicious PDF. Doing that is what
  CIRCLean and Dangerzone add, and it is too big for this project (see
  [Considered and Rejected](#considered-and-rejected)).
* User-space readers have bugs too. The gain is that a bug fires in a sandboxed process that holds
  nothing, not in the kernel.
* exFAT is the usual file system of SDXC cards and of many large sticks, and phase 1 cannot read
  it. Its FUSE driver's last release dates from 2023.
* The Zero has one USB 2.0 data port, which a hub shares, so large transfers are slow.
* Its audience is narrower than the CA's. It would be a bad idea if the owner would rather add the
  user-space readers to `pi0-pgp`, but that mixes hostile media with secrets in one boot, which is
  exactly what the station exists to avoid.

### 3. `pc-pgp`: the Air-gapped Environment on a PC (new platform `pc`)

**Purpose.** `pi0-pgp` on an x86-64 PC (an old laptop) that boots from a USB stick, with its own
screen and keyboard in place of a serial adapter, and much faster: the Zero has a single ARM1176
core, and `ykman`'s Python is slow on it. Who wants it: users who have no USB-TTL adapter, or who
find the Zero too slow.

**What the platform costs.**

* **Boot.** UEFI, from a GPT stick with an EFI system partition: the kernel as its own EFI stub at
  `\EFI\BOOT\BOOTX64.EFI`, with a built-in command line, or a UKI made with systemd's `ukify`
  (which needs Python's `pefile`). That is a third image layout in `lib/image.sh`, and firmware
  arguments for `lib/qemu.sh`: framework changes.
* **Kernel.** A `pc.config` layer (EFI, the EFI stub, xHCI and EHCI, the root on USB storage; ACPI
  and the CMOS clock are already in `x86_64.config`). New capabilities for a console on the screen
  (VT, the framebuffer console, simpledrm or efifb) and for keyboards (i8042 and AT keyboards for
  laptops, plus USB HID, which `hidraw.config` partly has). On purpose, no AHCI, NVMe or SD drivers:
  the internal disk cannot be reached at all.
* **Toolchain.** The x86-64 parts exist (`x86_64.config`, `hardening.x86_64.config`,
  `serial-console.x86_64.config`). On the owner's arm64 Mac it is a cross build, like `pi0`.
* **QEMU.** q35 with QEMU's own edk2 firmware, and tests on the serial console as now. On an arm64
  Mac this runs under TCG emulation only, which is slow. The CI runners are x86-64 with `/dev/kvm`
  (`phase.yaml`). The screen console can be tested only through screendumps.
* **Duplication.** Profiles share nothing, so `pc-pgp` would copy `pi0-pgp`'s 23 files and 28
  tests, and every change would be made twice. Whether profiles may share files is a framework
  question for the owner, and the largest recurring cost of this idea.

**Packages.** Those of `pi0-pgp`. No new upstream package is needed for a stub-booted kernel.
`ukify`, if chosen, needs `python/pefile`.

**Effort.** Large: a platform, a layout, two or three capabilities, the duplicated profile, and
hardware testing on more than one machine.

**Risks, and when it would be a bad idea.**

* The air gap is weaker. Most laptops have Wi-Fi and Bluetooth: the kernel has no drivers and no
  TCP/IP, but removing the card is the only certainty. Management engines (Intel AMT on vPro
  machines) can reach a wired network without the OS. The Zero has no radio on its specification,
  and stays in production until at least January 2030, so the Pi keeps the stronger guarantee.
* Without an initramfs, CPU microcode updates come only from the firmware.
* Real PCs vary (keyboards, graphics, USB controllers), and each one found broken is a support
  burden.
* Secure Boot has to be off, or enrolled with the owner's own keys: a decision to make.
* It is a bad idea if what users miss is only a console without an adapter: that is cheaper to
  answer on the Pi.


Comparison
----------

| Idea           | Platform | New recipes   | Kernel       | QEMU tests        | Effort | Main risk         |
|----------------|----------|---------------|--------------|-------------------|--------|-------------------|
| `pi0-ca`       | `pi0`    | 1, then 2-4   | none         | all but YubiKey   | M      | X.509 policy      |
| `pi0-sheepdip` | `pi0`    | 2-3, then 3-4 | none         | all               | S-M    | no exFAT at first |
| `pc-pgp`       | new `pc` | 0-1           | layer + caps | serial, no screen | L      | weaker air gap    |

New recipes: those of phase 1, then those that phase 2 adds. Effort: S, M and L are small, medium
and large.


Recommendation
--------------

Build `pi0-ca` first. It has the widest and clearest demand of the three, it uses upstream tools as
shipped (`openssl`, `ssh-keygen`, PKCS#11) with almost no glue of its own, and it reuses what
`pi0-pgp` has proven: keys in memory, a backup stick, a YubiKey through `pcscd`, and nothing kept.
It needs no Python or Rust, so it is smaller and quicker to build than `pi0-pgp`, and QEMU tests it
as thoroughly as `pi0-pgp`.

The cost, plainly: phase 1 is one new recipe (`openssh`, whose licence takes care), a different use
of the `openssl` recipe, a profile with its own files, manual page and tests, and the
`openssl.cnf` policy, which is most of the work. Phase 2 adds `pkcs11-provider` and either OpenSC
(one recipe) or `yubico-piv-tool` with `gengetopt` and `check` (three). Two decisions are the
owner's: whether a CA is its own profile or part of `pi0-pgp`, and which of OpenSC or
`yubico-piv-tool` serves the PIV card. `pi0-sheepdip` would make a good second profile, being cheap
and fully testable, once exFAT can be read.


Better as Additions to `pi0-pgp`
--------------------------------

These are features of the existing air-gapped environment, not profiles of their own:

* **Paper backups of the secret key.** `paperkey` 1.6 (GPL-2.0, 271 kB, no dependencies) prints
  only the secret parts of a key, with checksums, short enough to copy by hand. `qrencode` 4.1.1
  (LGPL-2.1) can show them as a QR code on the console.
* **An encrypted KEYS stick.** `cryptsetup` 2.8.9 needs `libdevmapper` (from LVM2), `json-c` (CMake)
  and `popt`, with OpenSSL as its crypto backend, and the kernel needs `DM_CRYPT`. Adiantum suits
  the ARM1176, which has no AES instructions. `systemd-cryptenroll` could bind the stick to the
  YubiKey's FIDO2 (`libfido2` exists). This contradicts `pi0-pgp`'s "there is no LUKS", so it is
  the owner's decision.


Considered and Rejected
-----------------------

| Idea                         | Why not                                                                |
|------------------------------|------------------------------------------------------------------------|
| Cryptocurrency cold signer   | SeedSigner does it on a Zero already (MIT, active), with a camera and  |
|                              | a screen that the project has no stack for; money raises every stake   |
| Document disarming, as       | Needs a container sandbox, LibreOffice or PyMuPDF, or Python parsers:  |
| Dangerzone or CIRCLean do it | far beyond 512 MB and a small image; Dangerzone is AGPL-3.0            |
| A networked appliance on     | The first TCP/IP: internet-facing code needs prompt updates, and these |
| `virt` (DNS, WireGuard)      | images are rebuilt and reflashed; it gives up the air-gap strengths,   |
|                              | and Alpine and others serve it already                                 |
| USB gadget devices (the Zero | QEMU's dwc2 emulation is host-only (merged in 2020; nothing newer      |
| as a token, a keyboard, a    | found), so nothing could be tested; and the Zero's one data port       |
| serial gadget)               | cannot be host and gadget at once                                      |
| Offline TOTP or passwords    | Needs a right clock (no battery, nothing kept), and the secrets are    |
|                              | needed where the network is; `ykman oath` already covers OATH          |
| Self-hosting build VM        | Needs a network, sudo, expect and git in the image; `Dockerfile.dev`   |
|                              | does this already, and builds on the target are slow                   |
| Pi Zero 2 W platform         | Wi-Fi and Bluetooth on the board weaken the air gap; `pc` covers speed |
| A `virt` twin of `pi0-pgp`,  | Profiles share nothing, so it is a full copy, and it tests a platform  |
| for faster tests             | that the system never runs on                                          |


Sources
-------

* OpenSSH release notes, latest 10.6p2 (2026-11-05): https://www.openssh.org/releasenotes.html.
  The OpenSSL 4 test (`30*|40*`), the PKCS#11 switch and the 8-part `LICENCE` were read in the
  10.6p2 tarball, `https://cdn.openbsd.org/pub/OpenBSD/OpenSSH/portable/openssh-10.6p2.tar.gz`.
* `ssh-keygen` with a CA key in PKCS#11 (`-D`) or an agent (`-U`):
  https://man.openbsd.org/ssh-keygen. Whether a FIDO key can be a CA key is not confirmed: the page
  does not say.
* OpenSSL 4.0, released 2026-04-14, not LTS, supported until 2027-05-14, engines removed:
  https://openssl-library.org/post/2026-04-14-openssl-40-final-release/
* pkcs11-provider 1.3.0, its Apache-2.0 `COPYING`, its `libcrypto >= 3.0.7` and its CI against
  OpenSSL master: https://github.com/openssl-projects/pkcs11-provider
* yubico-piv-tool 2.7.3 (2026-01-20): https://developers.yubico.com/yubico-piv-tool/Releases/. The
  BSD-2-Clause `COPYING`, `gengetopt`, the required `check`, and `GENERATE_MAN_PAGES` were read in
  the tarball's CMake files. Build prerequisites:
  https://docs.yubico.com/software/yubikey/tools/pivtool/piv-tool-setup.html
* OpenSC 0.27.1 (2026-03-31), LGPL-2.1: https://github.com/OpenSC/OpenSC
* CIRCLean: https://circl.lu/projects/CIRCLean and https://github.com/CIRCL/Circlean (last
  commit on master 2020-02-07, read through GitHub's API)
* f3 v10.0, and the libraries of its programs (its `Makefile`): https://github.com/AltraMayor/f3
* ntfs-3g 2026.9.28: https://github.com/tuxera/ntfs-3g. fuse-exfat 1.4.0:
  https://github.com/relan/exfat
* file 5.48: https://astron.com/pub/file/. gengetopt 2.23: https://ftp.gnu.org/gnu/gengetopt/
* paperkey 1.6: https://github.com/dmshaw/paperkey. libqrencode 4.1.1:
  https://github.com/fukuchi/libqrencode
* cryptsetup 2.8.9 and its build requirements: https://gitlab.com/cryptsetup/cryptsetup
* QEMU's dwc2 emulation, host mode only, merged in 2020:
  https://lore.kernel.org/qemu-devel/20200322222726.10244-6-pauldzim@gmail.com/T/
* Raspberry Pi Zero, in production until at least January 2030, with no radio among its
  specifications: https://www.raspberrypi.com/products/raspberry-pi-zero/
* SeedSigner: https://github.com/SeedSigner/seedsigner. Dangerzone:
  https://github.com/freedomofpress/dangerzone
* Licences and release dates not named above are those that GitHub's API reports from each
  repository's licence file. The exact SPDX form (`-only` or `-or-later`) is to be confirmed when
  a recipe is written.
