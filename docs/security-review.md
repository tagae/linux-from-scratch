Security Review
===============

Review of the tree as of 2026-11-26: the systems it builds, `pi0-pgp` above all, and the
build and supply chain behind them. Every claim below was checked against the sources, and where
marked against the built image (`image/pi0-pgp.img`, mounted read-only) or a QEMU boot of a copy of
it. Nothing was changed but this file.


Summary
-------

`pi0-pgp` is in good shape for what it sets out to be. The kernel has no IP stack, network
devices, radio, virtual terminal, input handlers or USB gadget mode; the image has no setuid file
and no file capability; the root and its subvolume are read-only, the SD card is root's, there is no
swap and no core dump, memory is zeroed as it is freed, polkit denies the regular account all but
four actions, and the daemons run in the sandboxes upstream ships. Sources are pinned by SHA-256, CI
runs with read-only tokens and no pull-request triggers. No finding is critical.

What matters most:

1. **The serial terminal's host is inside the air gap** (S1). Every passphrase and PIN typed on the
   Pi, and every byte it prints, passes through the computer at the other end of the TTL adapter,
   which can also type into the session. The documentation presents the Pi as air-gapped without
   saying that this computer must be trusted as much as the Pi.
2. **The key on the KEYS stick is protected with a work factor calibrated on a Pi Zero** (S2): the
   stick is the one lasting copy of the secret key, and a slow CPU makes GnuPG pick a low S2K count.
   One configuration line fixes it.
3. **The documented way to give `gpg-genkey` its passphrase echoes it on the terminal** (S4), so it
   lands in the scrollback of that same host and in the session's history.

The regular account's mounting of ext4 and BTRFS, an open decision, is assessed in [Mounting ext4
and BTRFS as the Regular Account](#mounting-ext4-and-btrfs-as-the-regular-account): the risk is in
the kernel's parsing, which the account changes little; the recommendation is to keep these mounts
root's, or to add fixed mount units, never a mechanism that lets the account choose mount options.


Threat Model
------------

Assets, in order: the OpenPGP secret key (in memory during a session, and passphrase-protected on
the KEYS stick); the passphrase, the YubiKey's PINs and its management key; the files moved between
sticks.

Adversaries that the system is meant to resist:

* Malware on the networked computers that the Pi exchanges data with: through the sticks, and
  through the serial terminal.
* A crafted USB device or file system, plugged in by the owner.
* Someone who gets the KEYS stick (lost, stolen, copied), or the SD card while the Pi is off.
* Someone with brief physical access to the running Pi.
* A compromised upstream source, download mirror, base image or CI action.

Out of scope: invasive hardware attacks (probing the package-on-package DRAM, cold boot, power and
EM side channels), a compromised owner build machine (it builds the image, so it is trusted by
construction), and the Broadcom firmware, which nothing can verify on the BCM2835.

The regular account and root are one person. The boundary between them guards against mistakes (a
`dd` over the SD card) and limits what a compromised program of the account can change, but the
account holds the keys, so escalating to root gains an attacker little that it needs.


Findings
--------

| Id  | Severity | Area                             | Status    |
|-----|----------|----------------------------------|-----------|
| S1  | High     | pi0-pgp: serial console          | Confirmed |
| S2  | Medium   | pi0-pgp: key backup protection   | Confirmed |
| S3  | Low      | pi0-pgp: console access          | Confirmed |
| S4  | Low      | pi0-pgp: gpg-genkey passphrase   | Confirmed |
| S5  | Low      | pi0-pgp: KEYS stick selection    | Confirmed |
| S6  | Low      | pi0-pgp: USB attack surface      | Confirmed |
| S7  | Low      | Build: Docker base images        | Confirmed |
| S8  | Low      | CI: action pinning               | Confirmed |
| S9  | Info     | pi0-pgp: boot integrity          | Confirmed |
| S10 | Info     | Releases: unsigned tags          | Confirmed |
| S11 | Info     | pi0-pgp: kernel attack surface   | Confirmed |
| S12 | Info     | Vulnerability scan               | Confirmed |

### S1: The Serial Terminal's Host Is Inside the Air Gap

The serial UART is the system's only console (`console=ttyAMA0,115200` in the image's
`cmdline.txt`; no `CONFIG_VT`, no `CONFIG_INPUT_EVDEV`), and the Quick Start has the owner log in
"through an USB TTL adapter" ([pi0-pgp.md:53](../profile/pi0-pgp.md)). The documentation lists the
serial console among the ways in and out ([pi0-pgp.md:17-19](../profile/pi0-pgp.md)), but calls the
system air-gapped and nowhere says what the other end of the cable can do.

The computer that runs the terminal sees every keystroke (the passphrase of
`PASSPHRASE=... gpg-genkey`, every PIN that `pinentry-tty` asks for) and every byte printed, and it
can type into the session at any time.

Scenario: the owner's everyday laptop runs the terminal and has malware that knows of this setup. It
records the passphrase as it is typed, waits for the session to be idle, and types
`base64 /mnt/keys/*-secret.asc` (or `gpg --export-secret-keys --armor`), reading the answer off the
line. With both, it has the key; nothing on the Pi can tell these keystrokes from the owner's.

Recommendation: say it plainly in [pi0-pgp.md](../profile/pi0-pgp.md), Privacy, and in
`pi0-pgp(7)`: the terminal's host is as trusted as the Pi, so use a computer that is itself offline
and kept for this (or booted from a live medium with its networking off), and close the terminal
program's log and scrollback after a session. Cost: documentation only.

The structural alternative, a local console (HDMI and a USB keyboard), takes the framebuffer, VT
and input capabilities, which the kernel deliberately lacks, and makes a USB keyboard live input: a
crafted USB device (S6) could then type. It trades one channel for another, so it is the owner's
decision; I do not recommend it over the documented trusted terminal.

### S2: The Key on the Stick Has a Pi Zero's Work Factor

`gpg-genkey` exports the secret key with `gpg --export-secret-keys`
([gpg-genkey:135](../profile/pi0-pgp/files/usr/bin/gpg-genkey)). GnuPG 2.5.24's agent protects the
exported key with S2K mode 3 over SHA-1, with the "standard" iteration count
(`agent/cvt-openpgp.c:1487-1490`), and that count, unless `s2k-count` is configured, is calibrated
on the running machine to take 100 ms by default (`agent/protect.c:191-209`,
`get_standard_s2k_count` at 250-256). The image ships no `gpg-agent.conf` (its `/etc/gnupg` holds
only `scdaemon.conf`).

So the count is what the Zero hashes in 100 ms. Under QEMU's emulation of the Zero on the Mac,
`gpg-connect-agent 'GETINFO s2k_count_cal' /bye` gives 8 829 952; the real ARM1176 was not measured,
and is likely slower. A current desktop calibrates to several times that, often to the cap of
65 011 712.

Scenario: the KEYS stick is lost, stolen or copied. The attacker guesses the passphrase offline, on
GPUs, paying per guess only the Zero's 100 ms of work. A strong passphrase still holds; a middling
one falls several times to an order of magnitude sooner than the same passphrase on a key exported
from a desktop. The stick is the only copy of the key that lasts, which is why this ranks second.

Recommendation: ship `/etc/gnupg/gpg-agent.conf` in `profile/pi0-pgp/files/`, beside
`scdaemon.conf` (the agent reads its system configuration from `/etc/gnupg`:
`agent/gpg-agent.c:1237`), with `s2k-count 65011712`, the largest count that OpenPGP's S2K encodes,
and a comment that says why. Cost: unlocking the secret key on the Pi takes longer (under a second
at QEMU's speed, likely a few on the board: `GETINFO s2k_time` tells); a profile file is in no
archive, so only the image is made anew. The README's advice of "a long passphrase" stays the main
protection.

### S3: Whoever Reaches the Console Is Root, and Stays Logged In

* root and the regular account have empty passwords by default (image: both shadow entries empty),
  which is documented and deliberate ([README](../README.md), Users).
* No idle limit ends a session: `/etc/profile` sets no `TMOUT`, and pulling the TTL adapter out
  does not hang up the line, as the Pi's UART has no carrier signal (the line stays logged in for
  the next adapter: suspected from the hardware, not tried on the board).
* root's passwordless login works only because of an ordering in shadow 4.20.2: `login.defs` has
  `PREVENT_NO_AUTH superuser`, which forbids it, but `src/login.c:863-875` tests the empty password
  on the passwd entry (`x`) before it reads the shadow entry. A shadow release that fixes that
  ordering locks root out of the console of every image without `LFS_ROOT_PASSWORD`.
* A password that the build sets is hashed with SHA-512 crypt at its default 5000 rounds
  ([lib/system.sh:212](../lib/system.sh)), and the hash is on the card for anyone who has it, while
  the system's own `login.defs` asks for yescrypt. The passwords also travel on the make command
  line (the host's shell history) and through the environment of every package build of the system
  phase ([lfs:60-61](../lfs)).

Scenario: the owner leaves the Pi with a session open, or with keys in memory and the agent's
passphrase cache (ten minutes) warm. Anyone who clips a TTL adapter to the header has the shell, or
logs in as root, and copies the keys out over the line.

Recommendation, cleanest first:

1. `readonly TMOUT=600` in `profile/pi0-pgp/files/etc/profile` (and the profile's other
   `/etc/profile`s if wanted): an idle shell exits. Cost: a session left at the prompt for ten
   minutes logs out, also in the middle of a long manual procedure.
2. Make the passwordless root explicit rather than accidental: `PREVENT_NO_AUTH no` in the
   `login.defs` that `package/shadow.sh` already edits. Cost: shadow's archive and every system's
   image are rebuilt.
3. Recommend `LFS_ROOT_PASSWORD` and `LFS_PASSWORD` in [pi0-pgp.md](../profile/pi0-pgp.md) for a
   card that leaves the owner's hands, and hash with yescrypt where the system's libxcrypt has it.
   Cost: a framework change in `_system_set_password`, which must keep SHA-512 for musl's
   `virt-busybox`.

### S4: The Documented Passphrase Input Echoes the Passphrase

`gpg-genkey` takes the passphrase from `-p` (the process list, which every account reads, as `/proc`
is not mounted with `hidepid`) or from `PASSPHRASE`, which the documentation recommends
([pi0-pgp.md:234-238](../profile/pi0-pgp.md), `pi0-pgp(7)` line 119). Typed at the prompt,
`PASSPHRASE='...' gpg-genkey ...` is echoed on the serial line, so it stays in the scrollback of the
terminal's host (S1), and in bash's in-memory history for the session (`HISTCONTROL=ignoreboth`
drops it only when the line starts with a space). It is also in the environment of `gpg-genkey`,
`gpg`, `gpg-agent` and `scdaemon` while the script runs, which only the account and root can read.
keyboxd, which would outlive the script, is not built (`keyboxd=no` in `package/gnupg.sh`).

Scenario: the passphrase that protects the stick (S2) sits in the laptop's terminal log next to the
session that printed the key's fingerprint.

Recommendation: when neither `-p` nor `PASSPHRASE` is given, have `gpg-genkey` ask on the terminal
with echo off, twice, and recommend that in the documentation; keep `PASSPHRASE` for the tests.
Cost: a few lines of the script (`stty -echo`), and the test that runs it unchanged. The passphrase
still crosses the terminal's host (S1), but no longer lands in its scrollback.

### S5: A Second Stick Labelled KEYS Can Receive the Key

`mnt-keys.mount` mounts `What=/dev/disk/by-label/KEYS`
([mnt-keys.mount:8](../profile/pi0-pgp/files/usr/lib/systemd/system/mnt-keys.mount)). With two
file systems labelled `KEYS`, the link follows one of them, and `gpg-genkey` writes the secret key,
the public key and the revocation certificate to it without asking which. The documentation says
"a key never lands on a stick that was plugged in for another purpose"
([pi0-pgp.md:176-177](../profile/pi0-pgp.md)), which holds only while one stick has the label.

Scenario: another stick in the hub was labelled `KEYS` elsewhere (a second backup, someone else's
stick, or one prepared to collect keys). The key lands on it.

Recommendation: `gpg-genkey` refuses to start unless exactly one file system has the label
(`blkid -o device -t LABEL=KEYS`, which the account can run, as it reads the USB devices) and names
the device it writes to. Cost: a few lines, and a test with two sticks.

### S6: USB Devices Are Parsed When Plugged In, Not Only When Mounted

The kernel authorizes every USB device (`CONFIG_USB_DEFAULT_AUTHORIZATION_MODE=1`). On plug, before
any mount: the kernel parses the descriptors, the HID report descriptors and the partition tables
(MBR, GPT); udev, as root and without a sandbox, probes every block device with libblkid, runs
`fido_id` on every hidraw device, and has the kernel scan any BTRFS superblock (`64-btrfs.rules`).
A FAT file system is mounted at the first access to its mount point by any process. The
documentation ties the risk to mounting ("Mounting a file system has the kernel read whatever it
holds", `pi0-pgp(7)` lines 91-92).

What a crafted device cannot do here, by construction: type commands (no VT, no evdev: HID keyboards
are inert), present a network or serial device (no drivers), or reach the SD card. What remains is a
memory-safety flaw in those parsers.

Recommendation: reword the advice to be about plugging in: an untrusted device goes into a Pi that
holds no secrets, and the Pi is powered off before secrets come in. Cost: documentation. Requiring
root to authorize each device (`USB_DEFAULT_AUTHORIZATION_MODE=0`, then `authorized` in sysfs) would
close the plug-time path, but has no upstream tool on this system and makes every stick a root
step; I do not recommend it.

### S7: Docker Base Images Float

`Dockerfile.bootstrap` starts `FROM debian:bookworm-slim` and `Dockerfile.dev` from
`debian:stable-slim`, by tag, and installs unpinned packages. The bootstrap container's compiler
builds the first toolchain, from which everything else descends, so the tag is the root of trust of
every image built through Docker, the owner's way of building.

Scenario: a compromised or replaced tag on the registry is pulled at the next
`docker compose run --build` and taints the bootstrap compiler; the pinned source hashes do not
detect it.

Recommendation: pin the bootstrap's base by digest (`FROM debian:bookworm-slim@sha256:...`) and move
it on purpose. Cost: a digest to update; `bin/invalidate --docker`, which treats the containers as
inputs, then invalidates the Docker archives, so each move is a cold Docker build. `Dockerfile.dev`
builds nothing that ships, and can stay as it is.

### S8: CI Actions Are Pinned by Tag

The workflows use `actions/checkout@v7`, `actions/cache/{restore,save}@v6`,
`actions/upload-artifact@v7` and `github/codeql-action/upload-sarif@v4`
(`.github/workflows/phase.yaml:60,121,131,139,186,197,235,242`, `lint.yaml:26`,
`vulnerabilities.yaml:40,74,82`). A moved tag runs new code in the job. The blast radius is small:
all are GitHub's own, every token is `contents: read` (the scan's adds `security-events: write`),
credentials are not persisted, and CI publishes no image.

Recommendation: pin each to a commit SHA with the version in a comment. Cost: a SHA to update per
action release. Separately, `vulnerabilities.yaml:51` selects the SBOM artifact by
`head_branch == "main"`, which a fork's branch named `main` also matches; that is harmless while no
workflow runs on pull requests, and needs `head_repository_id` checked if one ever does.

### S9: Nothing Verifies the SD Card

The BCM2835 boots whatever firmware, kernel and `cmdline.txt` the FAT partition holds; the system
does not check the card at boot. This is inherent and documented
([pi0-pgp.md:25-27](../profile/pi0-pgp.md)). Someone with the card for a few minutes can add
`init=/bin/sh`, or replace the kernel with one that copies keys to the next stick.

Recommendation: document the check that is possible: read the card back on a trusted machine and
compare it with the image, whose SHA-256 the SBOM records (`cmp image/pi0-pgp.img /dev/<card>`
ending in "EOF on image/pi0-pgp.img" means a match), and keep the card with the KEYS stick. Cost:
documentation.

### S10: Release Tags Are Unsigned

`bin/release` makes `git tag -a` ([bin/release:60](../bin/release)) under
`GIT_CONFIG_GLOBAL=bin/gitconfig` (line 34), so the owner's own `tag.gpgSign` is ignored; the
baseline tag `0.0.0` is unsigned. No image is published, so only the owner consumes the tags today.

Recommendation: `git tag -s` once releases matter to anyone else. Cost: a YubiKey touch per release.

### S11: Kernel Attack Surface Left to the Regular Account

Observed in a QEMU boot of the image: `user.max_user_namespaces` is 3551 (unprivileged user
namespaces, which `CONFIG_USER_NS` brings for `pcscd.service`), `kernel.dmesg_restrict` is 0, and
there is no LSM (`# CONFIG_SECURITY is not set`), so no Yama: a process of the account can ptrace
the account's `gpg-agent`. Modules are on (`CONFIG_MODULES=y`, unsigned) for one module,
`autofs4` (`CONFIG_AUTOFS_FS=m`, from `package/linux/systemd.config`).

In this threat model these only widen the path from the account to root, which holds nothing the
account lacks. Building `AUTOFS_FS` in and dropping `modules` from the profile's capabilities would
remove module loading altogether; it is a kernel rebuild for every profile that names `systemd`, for
a small gain, and I list it for completeness rather than as a recommendation.

### S12: The Scan's High Findings Have No Release to Move To

The last scan on GitHub (run of 2026-11-25) fails `pi0-pgp` on 16 findings of high severity with a
"fixed version": OpenSSL 4.0.3 (fixed in 4.0.4 or 4.1.1), Python 3.14.10 (3.14.11), glibc 2.44
(2.45), and five kernel CVEs fixed only in 7.x lines. On 2026-11-26 none of 4.0.4, 4.1.1, 3.14.11 or
2.45 is released (OpenSSL's releases end at 4.0.3 and 4.1.0, python.org's at 3.14.10, ftp.gnu.org's
at 2.44), and the kernel's CVE records give no fix in the 6.18 line. Waiting is right, as is the
absence of ignore entries. Exposure is also low: `libcrypto` serves only libfido2 and
`cryptography`, with no TLS and no network. Local `main` is 15 commits ahead of `github/main`, so
CI has not built or scanned HEAD.


Mounting ext4 and BTRFS as the Regular Account
----------------------------------------------

Today the regular account mounts nothing but the FAT file systems that systemd mounts for it; root
mounts ext4 and BTRFS ([pi0-pgp.md:179-189](../profile/pi0-pgp.md)), and QEMU confirms that
`mount` and `systemd-mount` are refused to the account.

What decides the risk is the kernel reading a crafted file system, and that does not depend on who
asks for the mount. ext4 and BTRFS are far larger parsers than FAT, and their maintainers do not
treat a crafted image as within their security model: syzbot reports flaws in both continually. A
mount made easier gets made more often, possibly while keys are in memory; that is the real cost of
the convenience. Who mounts matters only for the options: a file system made elsewhere can hold a
setuid-root program, and a mount without `nosuid` makes it root's for the account.

The ways to let the account mount, cleanest first:

| Way                                                       | Verdict                          |
|-----------------------------------------------------------|----------------------------------|
| Keep it root's (status quo)                               | Recommended                      |
| Fixed mount units, as for FAT, the options in the unit    | Acceptable                       |
| A polkit rule for `systemd-mount`, or for `manage-units`  | Never: the account picks options |
| `user` in an fstab, with a setuid `mount`                 | Never: it brings back setuid     |

* **Keep it root's.** Root has no password by default, so the cost is a login as root; the mount is
  a deliberate act, and the documented example already passes `nosuid,nodev,noexec`. Files that
  root copies in are root's, which the account then reads where the modes allow.
* **Fixed mount units.** A udev rule links a USB partition of type ext4 or BTRFS as
  `/dev/usb-ext4` or `/dev/usb-btrfs`, and a `.mount` with an `.automount`, like
  `mnt-usb\x2dstorage.mount`, mounts it with `nosuid,nodev,noexec`. The account chooses nothing but
  the moment. Ownership is the snag: ext4 and BTRFS keep their own owners, a new one's top directory
  is root's, and there is no `uid=`; an idmapped mount (`X-mount.idmap=`, which libmount reads and
  both file systems support; not tried here) maps the owners to the account. Cost: two units, a
  rule, an idmap that must be right for every stick, and every such stick parsed at first access,
  as FAT is today.

If the owner wants the convenience, the second is the way; otherwise the first, which costs nothing.


Checked and Found Sound
-----------------------

* No network at all: `INET`, `NETDEVICES`, `BT` off, no WLAN, no USB network or serial drivers, no
  USB gadget mode (resolved `.config` of the build). No VT, no evdev: a USB keyboard cannot type.
* Image (mounted read-only): no setuid or setgid file, no file capability, nothing world-writable
  but `/tmp` (sticky); `su`, `passwd`, `newgrp` and the like are present but not setuid, so the
  account cannot change identity; `/etc/shadow` 0600; system accounts locked; no `empower` group,
  so polkit's shipped `empower.rules` grants nothing; `wheel` has no members and the agent helper
  is not installed, so admin authentication cannot succeed.
* QEMU boot: root and its subvolume read-only (`btrfs property get / ro` is `true`), boot partition
  unmounted, no swap (`CONFIG_SWAP` off), `/run/memory` 0700 and `noswap`; the SD card is
  `root:disk 0660` and the account is not in `disk`; `systemctl is-system-running` is `running`.
* polkit's rule ([50-users.rules](../profile/pi0-pgp/files/etc/polkit-1/rules.d/50-users.rules))
  answers yes to four actions for `users` and no to everything else; accounts outside `users` fall
  to upstream defaults, which need an authentication that cannot happen. As the account, in QEMU:
  `run0`, `systemd-run`, `systemd-mount`, and `systemctl start` of `debug-shell.service`,
  `emergency.target` and `mnt-keys.mount` are all `Access denied`; `mount` says it needs root;
  `timedatectl set-time` works. systemd 261's world-connectable varlink services refuse the
  account too: `io.systemd.StorageProvider` `Acquire` of `/dev/mmcblk0` (and of `/dev/sda`) is
  `Permission denied`, and `RequestFactoryReset` fails. Their `ListVolumes` does show every block
  device's labels and UUIDs to any account, which reveals nothing that matters here.
* As the account, in QEMU: `/dev/sda` is `root:users 0660` and `/dev/mmcblk0` cannot be opened;
  `/run/memory` cannot be listed. A nested `bash -i` sets `HISTFILE=~/.bash_history`, which is in
  the memory of `/home`, so "nothing kept" holds even where "the shell saves no history" does not.
* `pcscd` and `polkit` run with upstream's sandboxes; `pcscd`'s socket is 0666 as upstream ships it,
  which on a one-person system lets the account use any reader, as documented.
* Kernel hardening: strong stack protector, `STRICT_KERNEL_RWX` and `STRICT_MODULE_RWX`, hardened
  usercopy, `FORTIFY_SOURCE`, freelist randomization and hardening, `RANDOM_KMALLOC_CACHES`,
  `LIST_HARDENED`, `INIT_STACK_ALL_ZERO`, `INIT_ON_FREE_DEFAULT_ON`; `DEVMEM`, `KEXEC`,
  `MAGIC_SYSRQ`, `DEBUG_FS`, `KALLSYMS`, `IO_URING`, `USERFAULTFD`, `PERF_EVENTS`,
  `LEGACY_TIOCSTI`, `LDISC_AUTOLOAD` and core dumps off; unprivileged BPF off, JIT always on and
  hardened (`net.core.bpf_jit_harden = 2`).
* Randomness: `bcm2835-rng` is the current hwrng with full credit, and the CRNG is ready 0.23 s into
  the (QEMU) boot. `gpg-genkey`'s uncredited YubiKey mix and its 61 s wait match the kernel's
  one-minute reseed interval; no seed outlives a boot.
* Memory: GnuPG's home is in the `noswap` tmpfs, `gpg-genkey` checks that before it starts, and the
  agent is killed however the script ends.
* Supply chain: every source and patch is pinned by SHA-256 and checked on every use (`check/lint`
  requires the pin), the Rust seed per architecture too; crates are fetched `--locked` and built
  `--offline`; Grype is pinned by digest. Archives carry digests that `unarchive` checks.
* Build privileges: the Docker build runs as the host's UID in a container with no root and no
  privileges; only the image step runs as root, still unprivileged. The Linux-host path runs
  `sudo --preserve-env ./lfs image build`, which runs the tools in `tools/` as root: inherent in
  making root-owned file systems, and only for whoever builds.
* CI: `contents: read` throughout, `persist-credentials: false`, no `pull_request` or
  `pull_request_target` triggers, caches saved from `main` only, artifacts limited to SBOMs and
  manifests.


Not Covered
-----------

* The real Pi: the firmware's behaviour, the hardware RNG on silicon, the UART with an adapter
  unplugged (S3), the S2K calibration and timing (S2), and whether a `reboot` leaves DRAM unzeroed
  for the next boot (that rests on systemd unmounting `/run/memory`, which frees and so zeroes its
  pages; not observed).
* The YubiKey paths (PINs, touch, `keytocard`), which QEMU cannot carry on pi0.
* Audits or fuzzing of upstream code (GnuPG, libblkid, the kernel's parsers, pcsc-lite, ykman and
  its Python dependencies).
* `virt` and `virt-busybox` beyond their kernels (no IP stack either) and their passwordless root
  on a VM console, which is fine for a VM.
* The security of the owner's Mac, the Colima VM and the GitHub account, which the build trusts.
