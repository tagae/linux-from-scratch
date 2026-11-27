Linux From Scratch
==================

[![Vulnerability scan](https://github.com/tagae/linux-from-scratch/actions/workflows/vulnerabilities.yaml/badge.svg)](https://github.com/tagae/linux-from-scratch/actions/workflows/vulnerabilities.yaml)

Build [Linux From Scratch](https://www.linuxfromscratch.org/lfs/view/systemd/)
and [additional packages](https://www.linuxfromscratch.org/blfs/view/stable-systemd/).

See [CONTRIBUTING.md](CONTRIBUTING.md) for how the project is put together.


Requirements
------------

A Linux host needs:

* to build the tools (`make tools`): a C and C++ toolchain, the `curl`, `wget`, `rsync`, `gawk`,
  `bison`, `python3` and `patchelf` commands, and CA certificates;
* to build images (`make image`): a working `sudo`;
* to boot images in a VM (`make qemu`): QEMU 11.1 or later, with `qemu-img`;
* to test them (`make test`): `expect` 5.45.3 or later;
* to sign images (`make sign`) and check their signatures (`make signature-check`): OpenSSH 8.2 or
  later, `jq`, `shasum` and `realpath`, and, to sign with a security key, an `ssh-keygen` with FIDO
  support or an agent that holds the key;
* to version the project: Git 2.36 or later, as the scripts read `bin/gitconfig` in place of the
  user's Git configuration.

Through Docker (`make docker-test`), containers build the tools and the images: the host, Linux or
not, needs Docker Compose instead of the first two, and the others to boot, test, sign and version.


Quick Start
-----------

Build a toolchain, use it to build a disk image, boot it, and run the tests of the profile (log in,
power off...):

```shell
make test
```

Or, through Docker:

```shell
make docker-test
```


Supported Platforms
-------------------

| Platform | Hardware             | Architecture |
|----------|----------------------|--------------|
| `virt`   | QEMU virtual machine | host         |
| `pi0`    | Raspberry Pi Zero    | ARMv6 (arm)  |


Profiles
--------

A *profile* is a whole system: kernel, init system and installed packages. It is named
`<platform>[-<name>]`, after the platform it runs on (`pi0-pgp` runs on `pi0`), and its name is the
key of everything built for it: package archives, system tree, boot files and image.

The profiles are `profile/<profile>.sh`, each documented in `profile/<profile>.md`:
[`virt`](profile/virt.md), the default, [`virt-busybox`](profile/virt-busybox.md) and
[`pi0-pgp`](profile/pi0-pgp.md).

Systems of different profiles can be built at once:

```shell
make -j docker-test docker-pi0-pgp-test
```


Kernel Capabilities
-------------------

A *kernel capability*, `package/linux/<capability>.config`, is a bundle of kernel options. It can
have a part for an architecture, `package/linux/<capability>.<architecture>.config`, and one for a
platform, `package/linux/<capability>.<platform>.config`.

| Capability       | Supports                                                     |
|------------------|--------------------------------------------------------------|
| `btrfs`          | BTRFS file systems, the root file system among them          |
| `console`        | The terminal layer that consoles build on                    |
| `devtmpfs`       | Device nodes in /dev, mounted before init starts             |
| `ext4`           | ext4 file systems, such as those of USB sticks and drives    |
| `fat`            | FAT file systems, such as the Pi's boot partition and sticks |
| `hardening`      | Kernel self-protection and CPU vulnerability mitigations     |
| `hidraw`         | HID devices on USB, such as security keys, as `/dev/hidraw*` |
| `modules`        | Loadable kernel modules, and their protection                |
| `overlay`        | Overlay file systems, such as memory over a read-only root   |
| `serial-console` | A UART as the kernel's console and early console             |
| `systemd`        | systemd requirements                                         |
| `usb`            | USB devices, also from user space through `/dev/bus/usb`     |
| `usb-storage`    | USB sticks, drives and card readers, with MBR and GPT tables |
| `zero-on-free`   | Zeroing of memory as it is freed, so secrets do not linger   |


Time & Date
-----------

Images are in UTC. To use another zone, install the `tzdata` package and pass the zone in
`LFS_TIMEZONE` (e.g., `make image LFS_PROFILE=pi0-pgp LFS_TIMEZONE=Europe/Berlin`). The clock stays
in UTC; the zone only changes how time is shown.

A system with systemd never starts its clock earlier than the time its image was made, which
systemd takes from the modification time of `/usr/lib/clock-epoch`. A board without a
battery-backed clock, the Raspberry Pi Zero, starts every boot at that time: `pi0-pgp` keeps nothing
across boots, so its clock is set by hand after each boot.


Localisation
------------

Localisation and native language support (NLS) are unsupported.


Users
-----

root has no password, so it logs in on the console without one, unless `LFS_ROOT_PASSWORD` sets
one.

A profile can have a regular account besides root. `LFS_USER` gives its name (`$USER` by default),
and `LFS_PASSWORD` its password (none by default, so that it logs in without one, like root):

```shell
make image LFS_PROFILE=pi0-pgp LFS_ROOT_PASSWORD='a root password' LFS_USER=alice LFS_PASSWORD='a password'
```


Tests
-----

`make test` boots the image in QEMU and runs the tests of the profile on it: the files of
`profile/<profile>/test/`, in the order of their names (`01-boot.exp`, `02-root-login.exp`...). The
first boots the machine and the last powers it off; each in between logs in on the console, checks
one thing, and logs out. The suite stops at the first failure, and says which test failed, why, and
what the console showed last. The tests boot the image through a temporary overlay, so they start
from the image as built and leave it unchanged.

The tests log in with the accounts that the image was built with, so they read the same variables
(`LFS_USER`, `LFS_PASSWORD`, `LFS_ROOT_PASSWORD`).

```shell
check/test pi0-pgp        # the same as make pi0-pgp-test, without building
```


Disk Images
-----------

When QEMU boots an image, the writes go to an overlay, `image/<key>.qcow2`, so that the image stays
unmodified.

### File Manifests

Next to the image, a plain text file lists every file of each of its file systems:
`image/<key>.root.txt` for the root file system, and `image/<key>.boot.txt` for the boot partition,
if there is one: one path per line, absolute from the file system's root, sorted by byte.

### Software Bill of Materials

Each image comes with an [SPDX 2.3][SPDX] document, `image/<key>.spdx.json`, which gives the hash of
the image and describes each upstream package ([design](docs/sbom-design.md)).

The SPDX project's validator checks the document, and [Grype](https://github.com/anchore/grype)
scans it for known vulnerabilities:

```shell
make sbom-check            # validates every document under image/ (fetches the validator from PyPI)
make vulnerability-check   # scans them with Grype, as CI does (fetches Grype, its data, CVE records)
```

### Signatures

A signature, `<sbom>.sig` next to an SBOM, vouches for that SBOM and, through the hash that the SBOM
gives, for its image ([design and limits](docs/sbom-design.md#signing)). The build signs nothing.
Once an image is made, sign it and check the signature:

```shell
make sign              # signs every SBOM under image/ (a security key asks for a touch for each)
make signature-check   # checks every SBOM under image/: its signature and its image
```

Both targets go by the SBOMs, so they skip an image without one, and they stop at the first
failure. To act on some SBOMs alone, give them as arguments to the scripts that the targets run,
`bin/sign` and `check/signature`.

Signing and checking require each image to be next to its SBOM and to match the hash in it, and the
SBOM to be named after the image as the image build names it: `<name>.spdx.json` for `<name>.img`
(or for an image `<name>`). So an image that is renamed after signing fails the check, even if its
SBOM is renamed to match.

The signing key is the file that `LFS_SIGNING_KEY` names, or else the file that git's
`user.signingkey` names: a private key, or a public key whose private half an agent holds.

```shell
make sign LFS_SIGNING_KEY=<key-file>
```

The trusted keys are those of `check/allowed_signers`, and signing keeps a signature only if one of
them made it. An SBOM has one signature, so a second signer's replaces the first. To trust another
signer, add a line to that file in the
[allowed signers](https://man.openbsd.org/ssh-keygen.1#ALLOWED_SIGNERS) format, with the same
principal and namespace restriction, and without the key's comment, which can hold personal data:

```text
lfs-release namespaces="sbom@linux-from-scratch" <key-type> <base64-key>
```

To check an image from elsewhere, put it in one directory with its SBOM and the signature, their
names unchanged. Then run the `check/signature` of a checkout that you trust, never one that came
with the image, because the script trusts the keys of its own checkout. A success names the image
that it verified.

```shell
<checkout>/check/signature <directory>/<name>.spdx.json
```

[SPDX]: https://spdx.github.io/spdx-spec/v2.3/
