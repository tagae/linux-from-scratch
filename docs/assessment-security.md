# Built systems and build system: security assessment

**First assessment:** 2026-10-11. **Updated:** 2026-10-12, after the fixes described in section 4.
The Evidence column records what the first pass found; the Status column and the "Done" notes
record what has changed since.

**Scope:** the `virt` (aarch64), `amd64` (x86-64) and `pi0` (armv6) `systemd` systems, and the
build system that produces them: `lfs`, `lib/`, `package/` and the `Makefile`. The Docker setup
(`Dockerfile.*`, `docker-compose.yaml`) is only a harness that shows the project builds from
scratch; it isn't how systems are delivered, so confining the containers is out of scope (see
section 2).

**Sources:**
- A static audit of each install tree: setuid files, permissions, accounts, `login.defs`, identity
  files.
- An ELF scan of every program and library (216 files on virt and amd64, 218 on pi0): PIE, RELRO,
  BIND_NOW, stack canaries, FORTIFY, NX, and BTI/PAC or IBT/SHSTK markings.
- Each built kernel's `.config`, against the Kernel Self Protection Project recommendations.
- The running systems under QEMU, started with `-snapshot` so that nothing persisted: systemd's
  compiled features, `systemd-analyze security`, sysctls, mounts, device nodes,
  `/sys/devices/system/cpu/vulnerabilities`, entropy sources, and an unprivileged user's view.
- A review of how sources are fetched, verified, built, cached and turned into images.

**Threat model.** These systems have no network stack, no network services and only a serial
console. The relevant attackers are therefore:
- a compromised local process or unprivileged account, escalating to root or the kernel;
- someone with physical access: the serial console, the SD card, or a USB stick (with the `usb`
  fragment);
- a compromised input to the build: an upstream tarball, a mirror, the Debian seed, or a cache on
  the build host;
- tampering with images between the build and the device.

## Summary

29 findings: 16 on the installed system and 13 on the build system. Severities are the first
pass's.

| Severity | Installed system | Build system |
|---|---|---|
| Critical | **Open:** S1 the same known root password in every image | — |
| High | **Fixed:** S2 password hashing, S3 kernel self-protection, S4 CPU mitigations | **Partly fixed:** C2 cached archives (archives done, sources open). **Dropped:** C1 |
| Medium | **Fixed:** S7 BPF, S8 setuid programs. **Open:** S5, S6, S9, S11. **Decided:** S10 modules stay | **Open:** C5, C7, C8, C9. **Partly fixed:** C6 (3 of 8 GitHub archives replaced). **Dropped:** C3, C4 |
| Low | **Open:** S12–S16 | **Open:** C10, C12. **Fixed:** C13. **Designed:** C11 |

**Already in good shape:**
- **No remote attack surface:** no TCP/IP stack, no listening network service, no SSH, no D-Bus.
- **Small kernel attack surface:** the allnoconfig base leaves out user namespaces, io_uring,
  userfaultfd, kexec, `/dev/mem`, `/dev/port`, `/proc/kcore`, magic SysRq, core dumps, kallsyms and
  kprobes.
- **Kernel self-protection:** stack protector, virtually mapped stacks, read-only kernel text and
  non-executable data, hardened usercopy, FORTIFY, slab hardening and randomization, KASLR on 64-bit
  platforms, CPU-vulnerability mitigations on amd64 and arm64, and unprivileged BPF off.
- **Userland:**
  - Every program is PIE, except glibc's `ldconfig` and `sln` on pi0; every ELF file has RELRO and a
    non-executable stack.
  - The cross compiler builds with stack protection by default (`--enable-default-ssp`).
  - systemd sets the `fs.protected_*` sysctls, and `randomize_va_space` is 2.
  - No setuid or setgid programs; new passwords use yescrypt.
- **Files:**
  - No world-writable files; `/etc/shadow` is 0600.
  - Images carry no `machine-id` and no random seed, so every device generates its own.
- **Build inputs:** every source tarball and patch is pinned by SHA-256, downloads go over HTTPS
  against a CA bundle built from Mozilla's data, and every package archive carries a digest that is
  checked before it is installed.

---

## 1. Installed system

| # | Severity | Status | Finding | Evidence (first pass) | Fix |
|---|---|---|---|---|---|
| S1 | Critical | Open | Every image has the same root password, `root`. Its SHA-512 hash is committed in `package/systemd/etc/shadow`, and the boot test relies on it | Identical `root:$6$//QBBNUuSpVPdw/S$…` in all three trees | Ship root locked (`root:!:…`), and provide the password per image. Either a build-time input writes the hash into the image, or systemd's `passwd.hashed-password.root` credential sets it at first boot; the credential is read by systemd-firstboot and sysusers, both currently disabled (`-Dfirstboot=false -Dsysusers=false`). The test then passes its own credential. Never commit a usable hash |
| S2 | High | **Fixed** | Passwords set on the system were hashed with traditional DES: truncated to 8 characters, 12-bit salt, cracked in seconds | `chpasswd` produced `tester:ML6u0274XioK2`. `login.defs` set no `ENCRYPT_METHOD` (shadow then defaults to DES), and libxcrypt was built with all hashes and the obsolete API (`libcrypt.so.1`) | **Done:** shadow is built `--with-yescrypt` and its `login.defs` gets `ENCRYPT_METHOD YESCRYPT`; libxcrypt is built with `hashes=strong,glibc obsolete_api=no` (soname now `libcrypt.so.2`). Verified: `chpasswd` writes `$y$…` hashes on all three systems |
| S3 | High | **Fixed** (see below for what is left out) | Most kernel self-protection features were off on all three kernels | `.config` of each kernel; pi0 logged "Kernel memory protection not selected by kernel config" | **Done:** `package/linux/hardening.config` (shared), plus per-architecture lines in `arm64.config` and `x86_64.config`. Verified in the three built `.config` files; the pi0 warning is gone. Boot times are unchanged |
| S4 | High (on real PCs) | **Fixed** | amd64 was built with `CPU_MITIGATIONS=n`, so it had no Spectre, Meltdown, MDS or retbleed mitigations | The boot log reported "Spectre V2 : Vulnerable" and "SMT mitigations: off" | **Done:** `CPU_MITIGATIONS` and every `MITIGATION_*` option in `x86_64.config` (allnoconfig turns each off despite its default), except the hypervisor-only `VMSCAPE`; on arm64, `UNMAP_KERNEL_AT_EL0` and `MITIGATE_SPECTRE_BRANCH_HISTORY`. amd64 now reports "Spectre V2 : Mitigation: Retpolines". What QEMU reports depends on the emulated CPU: virt still shows `spectre_v2: Mitigation: CSV2, but not BHB` and SSB "Vulnerable" on Apple silicon, and amd64 SSB "Vulnerable" (its default policy applies per process, to seccomp-confined ones, so it likely follows S5). Re-check on real hardware |
| S5 | Medium | Open | No seccomp and no Linux Security Module. systemd is also built without libseccomp, so `SystemCallFilter=` and `MemoryDenyWriteExecute=` in its own units do nothing | `systemd --version` shows `-SECCOMP`; `SECCOMP=n` and `SECURITY=n` in the kernels; `systemd-analyze security` rates udevd 8.7 EXPOSED and journald 7.2 MEDIUM | `CONFIG_SECCOMP_FILTER`, plus libseccomp as a new package and `-Dseccomp=enabled`. Also `CONFIG_SECURITY` with Yama (ptrace scope) and Landlock, both small |
| S6 | Medium | Open | Unprivileged users can read the kernel log, and kernel pointers are not hidden | `kernel.dmesg_restrict = 0` (`nobody` ran `dmesg`), `kernel.kptr_restrict = 0`, `/dev/kmsg` is 0644 | `CONFIG_SECURITY_DMESG_RESTRICT=y` (it doesn't need `CONFIG_SECURITY`); `kernel.kptr_restrict = 2` in a `sysctl.d` file from `system-files`, as `60-bpf.conf` already is |
| S7 | Medium | **Fixed** | Unprivileged users could load BPF programs, and the BPF JIT was not hardened | `kernel.unprivileged_bpf_disabled = 0`, `net.core.bpf_jit_harden = 0` | **Done:** `BPF_UNPRIV_DEFAULT_OFF=y` and `BPF_JIT_ALWAYS_ON=y` in `package/linux/systemd.config`, and `net.core.bpf_jit_harden = 2` in the files of the systemd package. Verified: `unprivileged_bpf_disabled = 2`, `bpf_jit_harden = 2`. systemd's own BPF (device and IP filters) runs as root and is unaffected |
| S8 | Medium | **Fixed** | Ten setuid-root programs, none of them needed: root is the only login account, and `newuidmap`/`newgidmap` serve user namespaces, which the kernels lack | `gpasswd chsh newgrp newuidmap chage su expiry newgidmap passwd chfn`, all `-rwsr-xr-x` | **Done:** shadow `--enable-subordinate-ids=no` (no `newuidmap`/`newgidmap`) and `make install suidperms=0755`, so the rest remain but only work for root. Verified: no setuid or setgid file in any tree, and `su` still works for root. Restore setuid only if non-root users appear |
| S9 | Medium | Open | Userland binaries are built without FORTIFY, without full RELRO, without stack-clash protection, and without arm64 BTI/PAC or x86 IBT/SHSTK markings | FORTIFY in 4 of 216 files (coreutils, sed and libc from their own builds); BIND_NOW in 79 (74 of them systemd's); BTI/PAC/IBT/SHSTK in none (unchanged by the fixes). `lib/system.sh` exports only `CFLAGS=-O2 LDFLAGS=-Wl,-s` | `CFLAGS="-O2 -D_FORTIFY_SOURCE=3 -fstack-clash-protection"` (stack-clash protection where the architecture supports it) and `LDFLAGS="-Wl,-s -Wl,-z,now"`, the same for C++. glibc `--enable-stack-protector=strong --enable-bind-now --enable-fortify-source`. Cross gcc `--enable-standard-branch-protection` (arm64) or `--enable-cet` (x86-64), so the markings become the default. Markings only take effect once every object of a program carries them, so glibc and libgcc must be built the same way. The kernel side (`ARM64_BTI`, `X86_KERNEL_IBT`) is already on; `X86_USER_SHADOW_STACK` becomes useful with it |
| S10 | Medium | Decided: modules stay | Kernel modules are enabled and unsigned, and there is a single one, `autofs4` | `CONFIG_MODULES=y`, `MODULE_SIG=n`; `lsmod` lists only `autofs4`; the only `=m` in `package/linux` is `AUTOFS_FS` | Dynamic module loading is kept on purpose (decision of 2026-10-12). If it ever needs hardening, sign the modules (`MODULE_SIG_FORCE`) rather than remove the loader |
| S11 | Medium | Open | Nothing protects the integrity of the root file system or the boot chain. The root is a read-write btrfs subvolume, the Pi's `cmdline.txt` and `config.txt` sit on an unprotected FAT partition, and amd64 has no boot loader, so there is no Secure Boot. Anyone with the SD card or the disk is root (`init=/bin/sh`) | `/proc/mounts`; `FS_VERITY`, `DM_VERITY` and `IMA` are off | Depends on the threat model. Physical attackers can't be kept out on a Pi Zero (no secure boot), but tampering could be made detectable: a dm-verity root with a read-write data area, which pairs with the A/B upgrade plan. On amd64, a signed unified kernel image under UEFI Secure Boot |
| S12 | Low | Open | pi0 has no driver for the board's hardware RNG, so it depends on jitter entropy | `HW_RANDOM=n`; `crng init done` at 9.7 s under QEMU, versus 1.1 s on virt with virtio-rng | `CONFIG_HW_RANDOM=y` and `CONFIG_HW_RANDOM_BCM2835=y` in `pi0.config` |
| S13 | Low | Open | debugfs and tracefs are built and mounted; only root can read them, but they expose a large kernel interface | `DEBUG_FS=y` and `FTRACE=y` come from `package/linux/systemd.config`, only so that systemd's `sys-kernel-debug`/`tracing` mounts succeed | Drop both; systemd skips mounts for file systems the kernel lacks |
| S14 | Low | Open | Leftovers of disabled features: accounts (`messagebus`, `systemd-journal-{gateway,remote,upload}`, `-network`, `-resolve`, `-timesync`, `-coredump`, `-oom`, `uuidd`) and enabled units (`systemd-network-generator`, `systemd-journald-audit.socket`, `systemd-factory-reset.socket`, `getty@tty1` with no virtual console) | `/etc/passwd`; `systemctl list-unit-files --state=enabled` | All accounts are locked with `/usr/bin/false` as their shell, so this is hygiene: drop them from `system-files`, and the units with systemd's own switches where they exist |
| S15 | Low | Open | Security events don't survive a reboot (volatile journal), and there is no audit subsystem | `journal-storage-default=auto` with no `/var/log/journal`; `AUDIT=n` | A deliberate trade-off for SD cards. On amd64, or for forensics, create `/var/log/journal` |
| S16 | Low | Open | Account defaults: no `/etc/securetty`, so root may log in on any terminal (only the serial console exists); `UMASK 022`; login failures are delayed 3 s but attempts are unlimited | `login.defs` | `UMASK 027`. A strong root password (S1) makes brute force over serial impractical |

**S3 in detail.** The kernel options now (`y` = on, `n` = off, `-` = not available on that
architecture), read from the three built `.config` files:

| Option | virt | amd64 | pi0 |
|---|---|---|---|
| `STACKPROTECTOR_STRONG`, `VMAP_STACK`, `SCHED_STACK_END_CHECK` | y | y | y |
| `STRICT_KERNEL_RWX`, `STRICT_MODULE_RWX` | y | y | y |
| `HARDENED_USERCOPY` (with `_DEFAULT_ON`), `FORTIFY_SOURCE` | y | y | y |
| `SLAB_FREELIST_RANDOM`, `SLAB_FREELIST_HARDENED`, `RANDOM_KMALLOC_CACHES`, `LIST_HARDENED` | y | y | y |
| `RANDOMIZE_BASE` (KASLR; x86 also `RELOCATABLE` and `RANDOMIZE_MEMORY`) | y | y | - |
| `ARM64_PTR_AUTH` (with `_KERNEL`), `ARM64_BTI` | y | - | - |
| `X86_KERNEL_IBT` | - | y | - |
| `CPU_MITIGATIONS`, and the arm64 and x86 mitigations (S4) | y | y | y |

Left out on purpose:

| Option | Why |
|---|---|
| `INIT_ON_ALLOC_DEFAULT_ON` (`INIT_STACK_ALL_ZERO` is already on) | Zeroes every allocation: a run-time cost on slow CPUs such as the Pi Zero |
| `BUG_ON_DATA_CORRUPTION` | Turns a detected corruption into a panic |
| `ARM64_SW_TTBR0_PAN` | Emulates user-memory protection in software, at a cost on every user-memory access |
| `ARM64_BTI_KERNEL` | Cannot be enabled when the compiler is GCC |
| `SHUFFLE_PAGE_ALLOCATOR` | Randomizes nothing unless the command line has `page_alloc.shuffle=1` |
| `X86_USER_SHADOW_STACK` | Of no use until programs are built with CET (S9) |
| `MITIGATION_VMSCAPE` | Only for hypervisor hosts (needs KVM) |

`SECURITY`, `SECCOMP`, `MODULES` and `HW_RANDOM` are covered in S5, S10 and S12.

## 2. Build system and supply chain

The Docker setup (`Dockerfile.*`, `docker-compose.yaml`) is a harness that shows the project builds
from scratch, not a delivery mechanism. Confining the containers was implemented and then reverted
for the complexity it added, so the findings about it (C1, C3, C4) are dropped. The findings about
what goes into the build, and about what comes out of it, stay.

| # | Severity | Status | Finding | Evidence (first pass) | Fix |
|---|---|---|---|---|---|
| C1 | High | Dropped | Build scripts and recipes are mounted read-write into the build containers. Any upstream `configure` or `Makefile` that runs during a build could rewrite `lfs`, `lib/` or `package/` on the host, including the pinned hashes | `docker-compose.yaml`: binds of `lfs`, `lib`, `package` without `read_only` | `read_only: true` on those binds. Done and reverted, as above |
| C2 | High | **Partly fixed** | Cached build outputs were trusted by name only. `lfs_archive_package` skipped any package whose archive existed in `archive/` (a host directory), and `get` skips extraction when the source directory already exists in the `source` volume. Whoever can write either one can put arbitrary binaries into images, and nothing would notice | `lib/package.sh` (`! [ -s $archive ] \|\| exit 0`), `lib/base.sh` (`[ -d $SOURCE_DIR/$extracted ] \|\| tar xf …`) | **Done for archives:** each archive's SHA-256 is written to `<archive>.sha256` when it is created and checked before it is unarchived, failing closed; an archive without its digest counts as not built and is rebuilt. Verified: an intact copy installs, a tampered one is refused, one without its digest is rebuilt. The digest sits next to the archive, so this catches corruption and changes made outside a build, not a build step that rewrites both. **Open for sources:** extract afresh from the verified tarball, or verify a stamp of the tarball's hash |
| C3 | Medium | Dropped | Both build containers run privileged, so upstream build scripts run with access to all host devices. Only the image step needs it (loop devices and mounts) | `privileged: true` for `bootstrap` and `scratch` | An unprivileged `scratch` plus a privileged `image` service. Done and reverted, as above |
| C4 | Medium | Dropped | The image step runs as root in a privileged container, using tools built from source (`mkfs.btrfs`, `kpartx`, `losetup`, `mount`, `tar`). A backdoored build tool would gain root on the Docker host VM | `Makefile`: `docker-image/%.img` runs `--user 0:0 scratch ./lfs image build`, and `image/%.img` runs `$(SUDO) ./lfs image build`; `lib/image.sh` | Build the file systems without mounting (`mkfs.btrfs --rootdir DIR --subvol rw:root/1`, plus `mtools` for the FAT partition). Not pursued, as the image step stays as it is |
| C5 | Medium | Open | Upstream signatures are never checked; the pinned hashes are trust-on-first-use. Nothing records how each hash was obtained, so a tarball tampered with on the mirror at pinning time would have been pinned as is | `verify_hash` only compares SHA-256 sums; GNU, kernel.org, sourceware, Python and CPAN all publish detached signatures | When pinning or bumping, verify the upstream signature against a key kept in the repository (e.g. `package/keys/`), and note it next to the hash. Optionally verify at fetch time too |
| C6 | Medium | **Partly fixed** | Eight sources were GitHub's auto-generated archives: systemd, the Pi kernel, the Pi firmware, jinja2, markupsafe, make-ca, multipath-tools and ninja. These are not signed, and their bytes are not guaranteed stable (GitHub changed the compression in 2023 and reverted it) | URLs of the form `…/archive/…` | **Done:** jinja2 and markupsafe now come from their PyPI sdists, and the Pi firmware from its release tarball (`raspi-firmware_<version>.orig.tar.xz`, 3.9 MB instead of the 172 MB repository archive); GitHub and PyPI publish the SHA-256s of these. The installed blobs are byte-identical to those of the old source. **Open:** systemd, the Pi kernel, make-ca, multipath-tools and ninja have no source release assets on GitHub (ninja ships binaries only), only tags. Pin the tag's commit, which is the stable identity, and verify signed tags where they exist (systemd, kernel) |
| C7 | Medium | Open | The fetch check fails open: `get` accepts a tarball with no hash, and `verify_hash` runs whichever `<algo>sum` the recipe names (`md5:` would be accepted) | `lib/base.sh`: `[ -z "$hash" ] \|\| verify_hash …` | Every recipe already pins SHA-256, so make the hash mandatory and accept `sha256`/`sha512` only |
| C8 | Medium | Open | Build steps can reach the network. Fetching and building are interleaved per package, so upstream build scripts run with network access | `lfs_archive_package` fetches and then builds in the same container | A fetch-all step (with hash verification), then build offline. Isolating the network is a container setting (`network_mode: none`), which the harness decision makes optional; the separate fetch phase is useful on its own |
| C9 | Medium | Open | Builds are not reproducible, so nobody can rebuild an image and compare it to verify it. Archives record build-time mtimes, the kernel embeds its build timestamp, user and host, and btrfs/FAT UUIDs are random. Reproducing builds is the main defence against a compromised build host | No `SOURCE_DATE_EPOCH`; `tar` without `--sort=name --mtime` | `SOURCE_DATE_EPOCH` from the release; `tar --sort=name --mtime=@$SOURCE_DATE_EPOCH --owner=0 --group=0 --numeric-owner`; `KBUILD_BUILD_TIMESTAMP`/`USER`/`HOST`; fixed file-system UUIDs. Then compare two builds; the second build stage already noted in TODO is the natural place |
| C10 | Low | Open | The bootstrap seed is mutable: a floating `debian:stable-slim` tag and unpinned `apt` packages. This is an accepted decision; the seed's compiler builds everything else (trusting trust) | `Dockerfile.bootstrap` | At no cost: pin the base image by digest. Long term: diverse double-compiling, or a bootstrappable-builds seed |
| C11 | Low | **Partly fixed** | No SBOM, no provenance, no signed images. Recipes already carry everything an SBOM needs (name, version, SPDX licence, source URL, hash), and archives now carry digests, but nothing ties an image to its inputs or lets a device check where an image came from | `image/*.img` is all an image ships with | **Done for the SBOM:** `docs/sbom-design.md`. Every image file gets `<image>.spdx.json`, an SPDX 2.3 document with the image's SHA-256 and each package's archive digest, version, SPDX licence and source (URL and SHA-256); it passes `pyspdxtools`. **Open:** publish a SHA-256 of each image and sign it with the SBOM (minisign or cosign); list the applied patches; add CPEs, so that the SBOM feeds CVE monitoring (kernel 7.3.1 and Pi kernel 6.18.60 above all) |
| C12 | Low | Open | Inputs from secondary hosts: ncurses from a mirror (`invisible-mirror.net`), procps-ng through SourceForge's redirector, PyPI's file host for jinja2 and markupsafe, and mandoc from its own site (`mandoc.bsd.lv`; its last release, 1.14.6, dates from 2021, and its pin was checked against the checksum file the site publishes). The texinfo pin was checked against its GPG signature. LFS patches are fetched from linuxfromscratch.org, which deletes old patch versions (TODO). All are hash-pinned, so this affects availability and provenance, not integrity | Recipes | Canonical hosts where they exist. Keep the patches in the repository |
| C13 | Low | **Fixed** | `./lfs install` to a block device partitioned and formatted it when it found no partitions, without asking | `lfs` (`DESTINATION` set to a block device), `lib/image.sh` `device()` | **Done:** `install` and `DESTINATION` are gone. `image build` formats a block device only when given it as its argument, and only with `ERASE` naming the same device; without it, `lfs` prints the device and stops. `sfdisk` no longer runs with `-f`, so a device that anything has mounted or opened, in this container or in another, is refused by the kernel's own check before the partition table is touched. Verified on a loop device standing in for a card: refused without `ERASE` and with another device's name, and, with a partition mounted by another container, refused with the partition table unchanged |

**Other aspects (licence compliance):** images now ship no licence texts, except the firmware's
`LICENCE.broadcom`, which its licence requires to travel with the blobs. Distributing the
GPL-licensed binaries (kernel, bash, coreutils, util-linux...) requires their licence texts and the
corresponding sources (or a written offer). Removing the documentation also removes the licence
texts that packages install under `/usr/share/doc`; a `/usr/share/licenses` that is kept, and keeping the `download/` tarballs with
each released image, would cover both. This belongs with the licence-policy TODO.

## 3. Remaining work, in suggested order

1. **S1:** lock root in the image and provide the password per image. The boot test (`./test`)
   logs in as root, so it needs a way to pass its own credential.
2. **Small changes in recipes and configuration:**
   - C7: mandatory SHA-256;
   - S6: `kptr_restrict`, and `dmesg_restrict` with `CONFIG_SECURITY`;
   - S12: the Pi's RNG driver;
   - S13: no debugfs or tracefs;
   - S14, S16: leftover accounts and units, `UMASK 027`.
3. **S9:** FORTIFY, `-z now` and stack-clash protection in the default flags, glibc and gcc
   hardening configure options, and BTI/PAC and CET markings.
4. **S5:** seccomp in the kernel and libseccomp for systemd, with Yama and Landlock.
5. **Supply chain:**
   - C5: signature-checked pins;
   - C6: pin the commits of the five remaining GitHub archives, and verify signed tags;
   - C2: sources;
   - C8: a separate fetch phase;
   - C9: reproducible builds;
   - C11: sign images and their SBOMs;
   - C10: pin the seed by digest.
6. **S11:** dm-verity together with the A/B upgrade work.

## 4. What was done, and how it was checked (2026-10-12)

The fixes were made together with the rest of the work in this period (the `docs` component, since removed, the
minimality and FHS changes, the Pi boot files), and verified by rebuilding virt, pi0 and amd64 from
scratch, booting each under QEMU, and re-measuring the trees and kernels.

| Check | Result |
|---|---|
| Password hashing (S2) | `chpasswd` writes `$y$…` hashes on all three systems; `ENCRYPT_METHOD YESCRYPT` is set; libcrypt is `libcrypt.so.2` |
| Setuid programs (S8) | 0 setuid or setgid files in each tree (was 10); `su` works for root |
| Kernel options (S3, S4) | Every requested option is in the built `.config` of the three kernels; boot times unchanged (virt 1.2 s, amd64 3.7 s, pi0 15 s) |
| Runtime (S3, S4, S7) | virt logs "KASLR enabled"; amd64 reports Spectre V2 "Mitigation: Retpolines"; `unprivileged_bpf_disabled = 2` and `bpf_jit_harden = 2` on all three |
| Archive digests (C2) | An intact archive installs; a tampered one is refused with nothing installed; one without its digest is rebuilt |
| ELF hardening (S9) | Unchanged: PIE for all programs but pi0's `ldconfig` and `sln`; RELRO and NX everywhere; FORTIFY in 4 files, BIND_NOW in 79, no BTI/PAC/IBT/SHSTK |
| Erasing a device (C13) | On a loop device standing in for a card, in the scratch container (with `kpartx`) and in a plain Debian 13 container with a live `/dev` and no `kpartx`, as on a Raspberry Pi running Raspberry Pi OS: `image build DEVICE` refuses without `ERASE` and with another device's name, leaving the device blank; with a partition mounted by another container it refuses and leaves the partition table unchanged; with `ERASE` it replaces a system that was there, and the device matches the install tree (861 entries, the boot files, `kernel.img` byte for byte). Not tried on real hardware |
| Release sources (C6) | jinja2 and markupsafe fetch from PyPI, and the Pi firmware from its release tarball; all match the published SHA-256s. pi0 rebuilt and booted: `/boot` holds the same blobs (identical checksums) |

Along the way, kernel options defaulting to `y` turned out not to survive `allnoconfig` (for example
`HARDENED_USERCOPY_DEFAULT_ON` and each x86 `MITIGATION_*`), so they are listed explicitly, and each
fragment was checked against a generated `.config` before building. The download cache is keyed by
file name, so a source that moves to another URL under the same file name must have its stale
download removed; the hash check refuses the stale file, so this fails closed.
