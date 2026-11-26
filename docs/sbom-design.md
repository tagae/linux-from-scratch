Image Software Bill of Materials
================================

**Status:** implemented in `lib/sbom.sh`, validated with `pyspdxtools`, and scanned by Grype in CI
(`.github/workflows/vulnerabilities.yaml`). The document names the upstream packages, with the CPEs
and PyPI purls that scanners match ([What Scanners Find](#what-scanners-find)). It leaves out the
patches applied to the sources, suppliers and signing ([Choices for Later](#choices-for-later)).

**Question:** how should each image get a Software Bill of Materials (SBOM), and can it be SPDX?

**Answer:** yes, SPDX fits this project with little new machinery:

- **Licences:** the recipes declare their licences as SPDX expressions (`package_license`).
- **Provenance:** every source is pinned by URL and SHA-256 (`package_source`,
  `package_source_hash`).
- **Identity:** the recipes name their upstream packages and versions, from which a CPE follows for
  most of them.


Format
------

**SPDX 2.3, JSON.** SPDX is an ISO standard (ISO/IEC 5962:2021, for 2.2.1). Version 2.3 is what
validators, scanners (Grype, Trivy) and Dependency-Track read. SPDX 3.0 (JSON-LD) models builds
better (build profile, provenance), but tools barely read it. The document maps onto 3.0 almost one
to one, so moving later is cheap.

CycloneDX would also work, but SPDX matches the licence expressions of the recipes, and licence
compliance is the other use of the SBOM here.


What an Image's SBOM Contains
-----------------------------

One document per image, `image/<profile>.spdx.json`, next to the image:

- **Document:** `documentNamespace` derived from the image's SHA-256; `created`, the time the image
  is made; `creators`, `Tool: lfs-<LFS_RELEASE>`.
- **Root package, the image:** its file name, `downloadLocation` `NONE` (it is published nowhere),
  `copyrightText` this project's own, the image's SHA-256, and `versionInfo` `LFS_RELEASE`, the
  version of this project's tree ([CONTRIBUTING.md](../CONTRIBUTING.md#versions-and-commits)). The
  document `DESCRIBES` it.
- **A package for each upstream package that the system installs** (`lfs_system_install`), once:
  `bash`, `glibc`, `linux`, `cryptography`... It has `name`, `versionInfo`, `packageFileName` (the
  source's file name), `checksums` (`package_source_hash`), `downloadLocation` (`package_source`),
  `licenseDeclared` and `licenseConcluded` (`package_license`), `description`, and `externalRefs`:
  purl and CPEs ([Identifiers](#identifiers)).
- **Relationships:** the image `CONTAINS` each package.
- **Extracted licences:** the text of each `LicenseRef-*` (the Pi firmware's, the time zone
  database's), kept in the declaring package's files directory as `LicenseRef-<name>.txt`, as the
  source is not unpacked when the archive comes from a cache.

**Example entry** (abridged):

```json
{
  "SPDXID": "SPDXRef-Package-bash-5.3",
  "name": "bash",
  "versionInfo": "5.3",
  "packageFileName": "bash-5.3.tar.gz",
  "checksums": [{ "algorithm": "SHA256", "checksumValue": "0d5cd869..." }],
  "downloadLocation": "https://ftp.gnu.org/gnu/bash/bash-5.3.tar.gz",
  "licenseDeclared": "GPL-3.0-or-later",
  "licenseConcluded": "GPL-3.0-or-later",
  "copyrightText": "NOASSERTION",
  "externalRefs": [{
    "referenceCategory": "PACKAGE-MANAGER",
    "referenceType": "purl",
    "referenceLocator": "pkg:generic/bash@5.3?download_url=https://ftp.gnu.org/gnu/bash/bash-5.3.tar.gz&checksum=sha256:0d5cd869..."
  }, {
    "referenceCategory": "SECURITY",
    "referenceType": "cpe23Type",
    "referenceLocator": "cpe:2.3:a:gnu:bash:5.3:*:*:*:*:*:*:*"
  }]
}
```

`licenseConcluded` repeats `licenseDeclared`: the recipes take `package_license` from the source's
own licence files, and no further audit stands behind the conclusion (ScanCode or ORT, in
[Tools](#tools), would give one). `copyrightText` stays `NOASSERTION` for the packages: the notices
are in the sources, which the SBOM's writer does not see, and nothing gathers them.

The document names packages, not the archives that the system build made of them: the archives are
published nowhere, so their digests would tell nobody anything, and scanners match the packages'
identities alone. A document that lists the sources alone, each with the CPE and purl of what was
built from it, gives every finding of one that lists the archives, whether the sources keep their
purpose (`SOURCE`) or not, and a few more for python and zlib, which Grype matches without a CPE as
well. A package that the system installs twice is named once. A package without a source, such as
`system-files`, holds this project's own files, which the image stands for. The `dev` component,
which a system doesn't get, stays out.

Beside the document, `image/<profile>.kernel-files` lists the files that the image's kernel was
built from, one path of the kernel's source tree per line. It is not in the image. The kernel's
recipe makes it, and the vulnerability scan reads it ([The Kernel](#the-kernel)).


Identifiers
-----------

Scanners find a package's vulnerabilities by an identifier that their databases know: the NVD's
CPE, for most packages, and a package URL of a language's ecosystem, for the Python libraries.

- **CPE.** `part:vendor:product:version`, which the document completes into a CPE 2.3 name. By
  default, the product is the package's name, the version its own, and the vendor the owner of the
  source's project on GitHub or GitLab (`openssl`, `libusb`, `yubico`), or else the name of the site
  that serves the source (`gnu` for `ftp.gnu.org`, `gnupg`, `kernel`, `python`). That is the NVD's
  name of 22 of the 35 upstream packages of a pi0 system with every feature. A recipe whose package
  the NVD names otherwise sets `package_cpe` to its CPEs: the NVD's `<name>_project` vendors
  (systemd, libffi, procps-ng), other vendors (shadow is `debian`, pcsc-lite `muscle`), a source on
  another site (zlib's on its author's GitHub, ncurses' on a mirror), the kernel
  (`o:linux:linux_kernel`), or `none` where the NVD has nothing (the Pi's firmware, npth, the time
  zone database). Scanners compare the version of the package with the vulnerable ones, so the
  document gives a package the version of its first CPE: the Pi's kernel, whose version is a tag of
  its fork (`stable_20261103`), is the 6.18.60 that the tag holds.
- **PyPI.** A package whose source is on PyPI has the purl `pkg:pypi/<project>@<version>`, and the
  name of its PyPI project (`python-dateutil`, not `python/dateutil`), which scanners match against
  the advisories of Python's packages: they look a Python package up by its name. It has no CPE.
- **Others.** A purl of type `generic`, with the source's URL and digest, which identifies the
  package to people, and to no vulnerability database.

The CPEs that the trial below confirmed are those with findings: gnu's bash, coreutils, gawk, gcc
and glibc, gnupg's gnupg, libgcrypt and libksba, debian's shadow, kernel's util-linux, libusb,
linux_kernel, openssl, python, systemd and zlib. The others rest on Buildroot's and cve-bin-tool's
tables, or on the rule alone (mandoc and ccid).


How It Is Produced
------------------

1. **Record what goes in.** `lfs_system_install` appends each package to a list for the system,
   `$LFS_WORK_DIR/sbom/$LFS_PROFILE`, which the system build empties first. A line holds what the
   recipe says: name, version, licence, source, source digest, CPEs and description. It is taken
   when the package is installed, because only then does the recipe see the variables it was built
   with (the package key, the Python version).
2. **Write the document.** `lib/sbom.sh` writes it from that list, in plain shell, at the end of
   `./lfs image build`, which knows the image's digest. The SBOM goes into place before the image,
   which tells that both are complete: an image with no SBOM is made anew.
3. **Check it.** `make sbom-check` runs `pyspdxtools --infile` on every `image/*.spdx.json`, which
   validates against the SPDX 2.3 model: licence expressions, identifiers and relationships. The
   validator, pinned in `check/Makefile`, is installed into a virtual environment under
   `work/check/`, so that CI, after each phase that makes an image, runs what a developer runs. The
   build, which runs with the tools alone, does not.
4. **Scan it.** CI keeps the SBOM of the image of each profile that its test phases make, and
   `.github/workflows/vulnerabilities.yaml` scans the latest of each with `make
   vulnerability-check` (`check/vulnerabilities`) after each run of CI on main, building nothing.
   The findings go to the run's summary and to GitHub's code scanning, where an alert can be
   dismissed with a reason. The scan leaves CI's result alone, and fails, as the README's badge
   shows, when a finding of high or critical severity has a fixed version. `check/grype.yaml` leaves
   out the findings that do not concern the images, each with its reason, and `check/kernel-vex`
   those of the kernel that its own CVE records show it does not have ([The Kernel](#the-kernel)).
   A developer's scan gives CI's verdict.


Tools
-----

No existing generator understands these recipes, so `lib/sbom.sh` writes the document itself. Open
source tools validate it, scan it and sign it. These are the well-known, maintained ones, all
Apache-2.0 unless noted; the scanners were tried on the documents ([What Scanners
Find](#what-scanners-find)).

- **Validate:** [`spdx-tools`](https://github.com/spdx/tools-python) (`pyspdxtools`), the SPDX
  project's own library. It fully validates 2.2 and 2.3; its 3.0 support is experimental and
  write-only, another reason to stay on 2.3.
- **Score:** [`sbomqs`](https://github.com/interlynk-io/sbomqs) scores an SPDX or CycloneDX file
  0–10 and checks it against NTIA minimum elements, BSI TR-03183-2 and OpenChain Telco. It shows
  which fields (supplier, CPE) are missing.
- **Scan:** [Grype](https://github.com/anchore/grype), the one scanner that finds the packages'
  vulnerabilities from an SBOM alone, given a CPE, or a PyPI purl for the Python libraries. It
  writes SARIF, which GitHub's code scanning takes.
- **Monitor:** [OWASP Dependency-Track](https://github.com/DependencyTrack/dependency-track) takes
  SBOMs per product and version and re-evaluates them as vulnerability feeds update. It needs a
  server; a scheduled scan in CI does the same for one image.
- **Triage:** [OpenVEX / `vexctl`](https://github.com/openvex/vexctl) records "not affected"
  decisions (e.g. a kernel CVE for a driver that is not built) so that they don't reappear on every
  scan. Grype takes them.
- **Licences:** [ScanCode Toolkit](https://github.com/aboutcode-org/scancode-toolkit) and
  [ORT](https://github.com/oss-review-toolkit/ort) scan the unpacked sources for licences, to check
  `package_license` and `licenseConcluded`, and to fill `copyrightText`: a one-off audit, not part
  of every build.
- **Convert:** [`bomctl`](https://github.com/bomctl/bomctl) converts and merges SPDX and CycloneDX.
  It describes itself as experimental, and has no diff. It is needed only if a consumer insists on
  CycloneDX.
- **Sign:** [cosign](https://github.com/sigstore/cosign),
  [minisign](https://github.com/jedisct1/minisign), GitHub's artifact attestations
  (`actions/attest-sbom`): see Signing in [Choices for Later](#choices-for-later).

**Prior art.** Yocto's `create-spdx` builds SPDX per recipe and image, and its `cve-check` takes a
CPE product name per recipe (`CVE_PRODUCT`), the same idea as `package_cpe`. Buildroot has
`make legal-info`, and names each package's CPE vendor and product (`<PKG>_CPE_ID_VENDOR`), a
source for ours.


What Scanners Find
------------------

The scanners were tried in CI in November 2026, on the documents that `lib/sbom.sh` writes for pi0,
with no features and with every feature; on the same documents with NVD CPEs and PyPI purls added
by hand; on both with old versions that have known vulnerabilities (bash 4.3, openssl 3.0.0, Linux
5.10.0, cryptography 3.2...), so that a scanner that finds nothing is told from one that matches
nothing; and on the binaries of the pi0 image.

- **Grype 0.121.0.** As written (`pkg:generic`): nothing, old versions included.
  `--add-cpes-if-none` guesses `<name>:<name>`, which is right for openssl, python, zlib, gnupg and
  libusb, and wrong for glibc, gcc, bash, the kernel, systemd, util-linux and shadow. With CPEs and
  PyPI purls: the packages whose CPE is NVD's, old versions of bash, glibc, openssl, systemd,
  util-linux and the kernel included, and the Python libraries through their purl, once named after
  their PyPI project (`cryptography`, not `python/cryptography`): 7151 findings on the old
  versions. ncurses 6.1 and procps-ng 3.3.16 matched nothing, so their CPEs need checking. On the
  image's binaries: nothing, as Syft knows packages from package databases and manifests, of which
  the tree has none.
- **Trivy 0.76.1.** Nothing, with or without CPEs, cryptography 3.2 included.
- **OSV-Scanner 2.7.0.** As written, it skips every package as unscannable; with purls, it reads the
  PyPI ones alone (24 findings for cryptography 3.2), and no CPE.
- **`sbom-cve-check` 1.3.5.** It cannot read the document: its SPDX 2 reader takes Yocto's
  documents alone, which link each package to its recipe's.
- **`cve-bin-tool` (main of October 2026).** It matches by bare name, against every vendor that has
  a product of that name: beside openssl's 25 findings and glibc's, other vendors' products
  (gentoo's and redhat's `linux`, microsoft's `python`, sonicwall's `firmware`) and distributions'
  advisories, 211 findings for pi0 with every feature, most of them false. CPEs add the kernel
  (138), and the false matches stay. On the binaries, it recognises gcc, glibc and the kernel alone
  (142 findings), not bash, systemd, util-linux, kmod or shadow. Its last release (3.4) reads NVD
  feeds that NVD has retired, and its database, fetched from NVD's API without a key, takes 24
  minutes and 3.8 GB.

On the current versions, with CPEs, Grype finds what an update fixes: an OpenSSL 4.0.1 gave 25
findings, all fixed in 4.0.3, and a Python 3.14.7 gave 14, 10 of them fixed in 3.14.10. The rest is
to triage, as `check/grype.yaml` does: CVEs that NVD gives every version, which upstream disputes
or which concern other builds (glibc's CVE-2010-4756 and CVE-2019-1010022 to -1010025, coreutils'
CVE-2016-2781, shadow's CVE-2013-4235, gcc's CVE-2023-4039 for AArch64's stack protector), and a
CVE of 2020 whose NVD range matches every kernel (CVE-2020-27815, a JFS flaw fixed in 5.10.4),
and the kernel's CVEs from 2016 to 2023.

Commercial services that are free for open-source projects add little: Snyk's `sbom test` reads
purls alone, of the types it knows; Sonatype OSS Index, Mend and Socket cover the packages of
language ecosystems. GitHub's code scanning, free for public repositories, takes Grype's SARIF, and
keeps its findings as alerts that can be dismissed with a reason.

### The Kernel

Grype matches the kernel by the version ranges of the NVD, which compare mainline version numbers:
6.18.60 is in the range of any CVE that is fixed in a later mainline version, though the long-term
line 6.18 may have the fix: most of the findings of a pi0 image, 194, are the kernel's.
`check/kernel-vex`, whose header has the method, reads the kernel's own CVE records,
which the kernel CNA publishes and the Pi's fork follows by version alone:

- The records give the version that fixes a CVE in each stable line: for the 128 findings with a
  fixed version, they said that 106 were fixed in 6.18 at or before 6.18.60.
- The records also name the files that a CVE concerns. The kernel's recipe saves the list of the
  files that its build read, as Kbuild records them (3,340 files for the Pi's kernel). Of the 22
  findings that the versions did not settle, 20 concern no source file of that list: ACPI, MPLS,
  Greybus, DPLL (the zl3073x driver), netfs, ksmbd, JFS, USB gadgets and sound among them.

What is left, CVE-2026-53091 (in net/core/dev.c, which the kernel builds) and CVE-2026-53106, is
read by a person.


Choices for Later
-----------------

- **Suppliers.** NTIA's minimum elements also ask for each component's supplier. A
  `package_supplier` (e.g. `Organization: GNU Project`), or `NOASSERTION` until then.
- **Patches.** The patches applied to a source are files of the package, `package/<name>/*.patch`,
  that `apply_patch` applies in a recipe's `prepare`, which does not run when the archive comes from
  the cache, so nothing records them. They would need to be declared by the recipe (a list that
  `prepare` applies and the SBOM reads), so that each becomes a package, with the digest of its
  file, and a `PATCH_APPLIED` relationship to its source.
- **Build tools.** The cross toolchain and the tools that built the system could be added with
  `BUILD_TOOL_OF` relationships. That makes the SBOM describe how the image was built, not only what
  it contains, which is most of what SPDX 3.0's build profile is for.
- **Reproducible builds.** `created` could then be `SOURCE_DATE_EPOCH`, and per-file SHA-256s of
  the tree (`hasFiles`) would let a device check its own files against the SBOM, at the cost of a
  much larger document.
- **Signing.** Signing the image's digest and the SBOM together (minisign or cosign) ties the SBOM
  to the image that was published.
