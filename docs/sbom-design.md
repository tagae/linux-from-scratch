# SBOMs for images: design

**Status:** implemented in `lib/sbom.sh`, validated with `pyspdxtools`. Not yet: CPEs and PyPI purls,
without which no scanner finds a vulnerability in it (see *What scanners find*), the patches applied
to the sources, suppliers and signing (see *Choices for later*). A system whose features install
the same package twice (openssl with fido2 and yubikey-manager) gets a document that `pyspdxtools`
rejects, as the two archives get the same identifier.

**Question:** how should each image get a Software Bill of Materials, and can it be SPDX?

**Answer:** yes, SPDX fits this project with little new machinery.
- **Licences:** the recipes already declare their licences as SPDX expressions (`package_license`).
- **Provenance:** every source is pinned by URL and SHA-256 (`package_source`,
  `package_source_hash`).
- **Built artefacts:** every package archive now carries its own SHA-256 (`<archive>.sha256`).

What's missing is a record of which archives went into a system, and a writer for the format.

## Format

**SPDX 2.3, JSON.** SPDX is an ISO standard (ISO/IEC 5962:2021, for 2.2.1). Version 2.3 is what
validators, scanners (Grype, Trivy) and Dependency-Track read today. SPDX 3.0 (JSON-LD) models
builds better (build profile, provenance), but tools barely read it yet. The document maps onto 3.0
almost one to one, so moving later is cheap.

CycloneDX would also work, but SPDX matches the licence expressions the recipes already use, and
licence compliance is the other use of the SBOM here (see the licence note in the security
assessment).

## What an image's SBOM contains

One document per image, `image/<SYSTEM_KEY>.spdx.json`, next to the image:

| SPDX element | Here | Fields |
|---|---|---|
| Document | the SBOM | `documentNamespace` derived from the image's SHA-256; `created` is the time the image is made (`SOURCE_DATE_EPOCH` when builds become reproducible); `creators`: `Tool: lfs-<LFS_RELEASE>`, as the scratch container has no git history to describe |
| Package (root) | the image | file name, SHA-256 of the image; the document `DESCRIBES` it |
| Package | each archive installed into the system (`lfs_system_install`): `bash`, `glibc`, `linux`, `firmware`, ... | `name`, `versionInfo`, `packageFileName` = archive name, `checksums` = the archive's SHA-256, `licenseDeclared` = `package_license`, `description`, `externalRefs`: purl (and CPE, see below) |
| Package | each upstream source | `downloadLocation` = `package_source`, `checksums` = `package_source_hash`, `primaryPackagePurpose: SOURCE` |
| Relationships | | image `CONTAINS` each archive; each archive `GENERATED_FROM` its source (not yet: patches `PATCH_APPLIED` to their source) |
| Extracted licences | `LicenseRef-*` (the Pi firmware's, the time zone database's) | the licence text, kept in the declaring package's files directory as `LicenseRef-<name>.txt`: the source may not be unpacked when the archive comes from a cache |

**Example entry** (abridged):

```json
{
  "SPDXID": "SPDXRef-Package-bash",
  "name": "bash",
  "versionInfo": "5.3",
  "packageFileName": "bash-5.3.tar.xz",
  "checksums": [{ "algorithm": "SHA256", "checksumValue": "<from bash-5.3.tar.xz.sha256>" }],
  "licenseDeclared": "GPL-3.0-or-later",
  "licenseConcluded": "NOASSERTION",
  "copyrightText": "NOASSERTION",
  "downloadLocation": "NOASSERTION",
  "externalRefs": [{
    "referenceCategory": "PACKAGE-MANAGER",
    "referenceType": "purl",
    "referenceLocator": "pkg:generic/bash@5.3?download_url=https://ftp.gnu.org/gnu/bash/bash-5.3.tar.gz&checksum=sha256:0d5cd869..."
  }]
}
```

The `dev` component, which a system doesn't get, stays out. If it is unpacked into a system by
hand, it is a separate archive and can be added the same way.

## How it is produced

1. **Record what goes in.** `lfs_system_install` appends each package to a list for the system,
   `$WORK_DIR/sbom/$SYSTEM_KEY`, which the system build empties first. A line holds the archive's name
   and SHA-256 (the digest that the install has just checked), and what the recipe says: name,
   version, licence, source, source digest and description. It is taken when the package is
   installed, because only then does the recipe see the variables it was built with (the package
   key, the Python version). This is the only change to the system build.
2. **Write the document.** `lib/sbom.sh` does it from that list, at the end of `./lfs image build`,
   which knows the image's digest, and writes next to the image on the host. It's plain shell,
   `printf` plus a small JSON string-escaping helper, like the rest of the framework. The SBOM goes
   into place before the image, which tells that both are complete: an image with no SBOM is made
   anew.
3. **Check it.** `pyspdxtools --infile image/<key>.spdx.json` validates against the SPDX 2.3 model:
   licence expressions, identifiers and relationships. Not part of the build, which runs with the
   tools alone.

## Tools to use

No existing generator understands these recipes, so `lib/sbom.sh` writes the document itself. Open
source tools then validate it, scan it and sign it. These are the well-known, maintained ones; all
are Apache-2.0 unless noted. The scanners were tried on our documents (see *What scanners find*).

| Job | Tool | Why / caveat |
|---|---|---|
| Validate | [`spdx-tools`](https://github.com/spdx/tools-python) (`pyspdxtools`) | The SPDX project's own library. Fully validates 2.2 and 2.3; 3.0 is experimental and write-only. Another reason to stay on 2.3. |
| Score | [`sbomqs`](https://github.com/interlynk-io/sbomqs) | Scores an SPDX or CycloneDX file 0–10 and checks it against NTIA minimum elements, BSI TR-03183-2 and OpenChain Telco. Shows which fields (supplier, CPE) are still missing. |
| Scan | [Grype](https://github.com/anchore/grype) | The one scanner that finds our packages' vulnerabilities, from an SBOM alone, once they carry a CPE, or a PyPI purl for the Python libraries. Writes SARIF, which GitHub's code scanning takes. |
| Monitor | [OWASP Dependency-Track](https://github.com/DependencyTrack/dependency-track) | Takes SBOMs per product and version and re-evaluates them as vulnerability feeds update. Needs a server; a scheduled scan in CI does the same for one image. |
| Triage | [OpenVEX / `vexctl`](https://github.com/openvex/vexctl) | Records "not affected" decisions (e.g. a kernel CVE for a driver we don't build) so they don't reappear on every scan. Grype takes them. |
| Licences | [ScanCode Toolkit](https://github.com/aboutcode-org/scancode-toolkit), [ORT](https://github.com/oss-review-toolkit/ort) | Scan the unpacked sources for licences, to check `package_license` and fill `licenseConcluded`. A one-off audit, not part of every build. |
| Convert | [`bomctl`](https://github.com/bomctl/bomctl) | Converts and merges SPDX and CycloneDX. Describes itself as experimental, and has no diff yet. Only needed if a consumer insists on CycloneDX. |
| Sign | [cosign](https://github.com/sigstore/cosign), [minisign](https://github.com/jedisct1/minisign), GitHub's artifact attestations (`actions/attest-sbom`) | See Signing below. |

**Prior art.** Yocto's `create-spdx` builds SPDX per recipe and image, and its `cve-check` takes a
CPE product name per recipe (`CVE_PRODUCT`), the same idea as `package_cpe`. Buildroot has
`make legal-info`, and names each package's CPE vendor and product (`<PKG>_CPE_ID_VENDOR`), a
source for ours.

## What scanners find

Tried in CI in November 2026, on the documents that `lib/sbom.sh` writes for pi0, with no features
and with every feature; on the same documents with NVD CPEs and PyPI purls added by hand; on both
with old versions that have known vulnerabilities (bash 4.3, openssl 3.0.0, Linux 5.10.0,
cryptography 3.2...), so that a scanner that finds nothing is told from one that matches nothing;
and on the binaries of the pi0 image.

| Scanner | As written (`pkg:generic`) | With CPEs and PyPI purls | The image's binaries |
|---|---|---|---|
| Grype 0.121.0 | Nothing, old versions included. `--add-cpes-if-none` guesses `<name>:<name>`, which is right for openssl, python, zlib, gnupg and libusb, and wrong for glibc, gcc, bash, the kernel, systemd, util-linux and shadow | The packages whose CPE is NVD's, old versions of bash, glibc, openssl, systemd, util-linux and the kernel included; the Python libraries through their purl, once named after their PyPI project (`cryptography`, not `python/cryptography`): 7151 findings on the old versions. ncurses 6.1 and procps-ng 3.3.16 matched nothing, so their CPEs need checking | Nothing: Syft knows packages from package databases and manifests, of which the tree has none |
| Trivy 0.76.1 | Nothing | Nothing, cryptography 3.2 included | — |
| OSV-Scanner 2.7.0 | Skips every package, as unscannable | The PyPI purls alone (24 for cryptography 3.2): it reads no CPE | — |
| `sbom-cve-check` 1.3.5 | Cannot read it: its SPDX 2 reader takes Yocto's documents alone, which link each package to its recipe's | — | — |
| `cve-bin-tool` (main of October 2026) | Matches by bare name, against every vendor that has a product of that name: beside openssl's 25 and glibc's, other vendors' products (gentoo's and redhat's `linux`, microsoft's `python`, sonicwall's `firmware`) and distributions' advisories, 211 findings for pi0 with every feature, most of them false | Adds the kernel through its CPE (138); the false matches stay | Recognises gcc, glibc and the kernel alone (142 findings), not bash, systemd, util-linux, kmod or shadow |

`cve-bin-tool`'s last release (3.4) reads NVD feeds that NVD has retired, and its database, fetched
from NVD's API without a key, takes 24 minutes and 3.8 GB.

On the current versions, with CPEs, Grype finds what an update fixes: openssl 4.0.1 (25 CVEs, fixed
in 4.0.2 and 4.0.3), python 3.14.7 (14, fixed up to 3.14.10), util-linux 2.42.2 (one of 3, in
2.42.3), glibc 2.44 (6 of 17, in 2.45) and the kernel, 6.18.60 (126 of 193 with a fixed version).
The rest is to triage: CVEs that NVD gives every version, which upstream disputes or which concern
other builds (glibc's CVE-2010-4756 and CVE-2019-1010022 to -1010025, coreutils' CVE-2016-2781,
shadow's CVE-2013-4235, gcc's CVE-2023-4039 for AArch64's stack protector), and the kernel's 67
CVEs from 2016 to 2023. Grype cannot tell which of the kernel's CVEs concern code that a kernel
configured from `allnoconfig` does not build.

A document that lists the sources alone, each with the CPE and purl of what was built from it, and
none of the archives, gives every finding of the one with archives, whether the sources keep their
purpose (`SOURCE`) or not, and a few more for python and zlib, which Grype matches without a CPE as
well.

Commercial services that are free for open-source projects add little: Snyk's `sbom test` reads
purls alone, of the types it knows; Sonatype OSS Index, Mend and Socket cover the packages of
language ecosystems. GitHub's code scanning, free for public repositories, takes Grype's SARIF, and
keeps its findings as alerts that can be dismissed with a reason.

## Choices for later

- **CVE matching needs identifiers that scanners know.** purls of type `generic` identify packages
  uniquely but match no vulnerability database. NVD matches by CPE, so recipes would need a
  `package_cpe` (vendor and product), e.g. `cpe:2.3:a:gnu:bash:5.3`,
  `cpe:2.3:o:linux:linux_kernel:7.3.1`, `cpe:2.3:a:systemd_project:systemd:261.2`. That's about
  thirty recipes for what the systems ship. The Pi's kernel, whose version is a tag of its fork
  (`stable_20261103`), needs the upstream version it carries (6.18.60). The Python libraries need a
  `pkg:pypi` purl and their PyPI name, which their sources' URLs on PyPI give.
- **Suppliers.** NTIA's minimum elements also ask for each component's supplier. A `package_supplier`
  (e.g. `Organization: GNU Project`), or `NOASSERTION` until then.
- **Patches.** The patches applied to a source (`patch_source`, `apply_patch`) are calls in a recipe's
  `prepare`, which does not run when the archive comes from the cache, so nothing records them. They
  would need to be declared by the recipe (a list that `prepare` applies and the SBOM reads), so
  that each becomes a package with a `PATCH_APPLIED` relationship to its source.
- **Build tools.** The cross toolchain and the tools that built the system could be added with
  `BUILD_TOOL_OF` relationships. That makes the SBOM describe how the image was built, not only what
  it contains, which is most of what SPDX 3.0's build profile is for.
- **Files.** Per-file SHA-256s of the tree (`hasFiles`) would let a device check its own files
  against the SBOM. That's larger, and best left for after reproducible builds.
- **Signing.** Signing the image's digest and the SBOM together (minisign or cosign) ties the SBOM to
  the image that was published.

**Effort:** steps 1–3 are a few hundred lines (mostly `lib/sbom.sh`) plus a validation run per
platform. CPEs and suppliers are recipe metadata, which can be added package by package.
