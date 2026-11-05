# SBOMs for images: design proposal

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
| Document | the SBOM | `documentNamespace` derived from the image's SHA-256; `created` from `SOURCE_DATE_EPOCH` when builds become reproducible; `creators`: `Tool: lfs-<git describe>` |
| Package (root) | the image | file name, SHA-256 of the image; the document `DESCRIBES` it |
| Package | each archive installed into the system (`lfs_system_install`): `bash`, `glibc`, `linux`, `firmware`, ... | `name`, `versionInfo`, `packageFileName` = archive name, `checksums` = the archive's SHA-256, `licenseDeclared` = `package_license`, `description`, `externalRefs`: purl (and CPE, see below) |
| Package | each upstream source | `downloadLocation` = `package_source`, `checksums` = `package_source_hash`, `primaryPackagePurpose: SOURCE` |
| Relationships | | image `CONTAINS` each archive; each archive `GENERATED_FROM` its source; patches `PATCH_APPLIED` to their source |
| Extracted licences | `LicenseRef-*` (the Pi firmware's) | the licence text, taken from the source |

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

## How it would be produced

1. **Record what goes in.** `lfs_system_install` appends each package (product and archive name) to
   a list for the system, `$WORK_DIR/$SYSTEM_KEY/packages`, which the build wipes and rewrites with
   the tree. This is the only change to the system build.
2. **Write the document.** A new `lib/sbom.sh` does it from that list. For each package it sources
   the recipe through `lfs_source_package` (as `lfs_package_version` does) and reads the archive's
   digest. It runs at the end of `./lfs image build`, which knows the image's digest, and writes next
   to the image on the host. It's plain shell, `printf` plus a small JSON string-escaping helper,
   like the rest of the framework; Python is available in the tools if escaping ever gets hard.
3. **Check it.** Validate against the SPDX 2.3 schema (`pyspdxtools`, on the host or as a tool), and
   check that every package in the list appears with a digest that matches.

## Tools to use

No existing generator understands these recipes, so `lib/sbom.sh` writes the document itself. Open
source tools then validate it, scan it and sign it. These are the well-known, maintained ones; all
are Apache-2.0 unless noted. Versions and release dates were not checked, so look at each project's
releases page before pinning one.

| Job | Tool | Why / caveat |
|---|---|---|
| Validate | [`spdx-tools`](https://github.com/spdx/tools-python) (`pyspdxtools`) | The SPDX project's own library. Fully validates 2.2 and 2.3; 3.0 is experimental and write-only. Another reason to stay on 2.3. |
| Score | [`sbomqs`](https://github.com/interlynk-io/sbomqs) | Scores an SPDX or CycloneDX file 0–10 and checks it against NTIA minimum elements, BSI TR-03183-2 and OpenChain Telco. Shows which fields (supplier, CPE) are still missing. |
| Scan | [Grype](https://github.com/anchore/grype) | Scans an SBOM without the image; large user base. Matches NVD by CPE, so recipes need `package_cpe`. Its CPE matching is switched off for ecosystems covered by GitHub advisories, which is not our case, but check it on a real SBOM. |
| Scan | [Trivy](https://github.com/aquasecurity/trivy) | Reads SPDX too, but matches mainly on purl and OS package types, so `pkg:generic` will find little. Use as a second opinion. |
| Scan (embedded) | [`sbom-cve-check`](https://github.com/bootlin/sbom-cve-check) (Bootlin, GPL-2.0) | Made for embedded Linux and Yocto. Reads SPDX 2.2/3.0, uses NVD and the CVE List, drops kernel CVEs for source files not compiled in, and takes OpenVEX annotations. Young (first release Dec 2025) and documented for Yocto, so try it on our SBOM before relying on it. |
| Scan (binaries) | [`cve-bin-tool`](https://github.com/intel/cve-bin-tool) | Intel's. Scans the built tree's binaries for known components and can read SBOMs, so it cross-checks the recipes' versions independently. Emits VEX (CycloneDX, CSAF, OpenVEX). |
| Monitor | [OWASP Dependency-Track](https://github.com/DependencyTrack/dependency-track) | Takes SBOMs per product and version and re-evaluates them as vulnerability feeds update. Worth it once there are several images or releases. |
| Triage | [OpenVEX / `vexctl`](https://github.com/openvex/vexctl) | Records "not affected" decisions (e.g. a kernel CVE for a driver we don't build) so they don't reappear on every scan. |
| Licences | [ScanCode Toolkit](https://github.com/aboutcode-org/scancode-toolkit), [ORT](https://github.com/oss-review-toolkit/ort) | Scan the unpacked sources for licences, to check `package_license` and fill `licenseConcluded`. A one-off audit, not part of every build. |
| Convert | [`bomctl`](https://github.com/bomctl/bomctl) | Converts and merges SPDX and CycloneDX. Describes itself as experimental, and has no diff yet. Only needed if a consumer insists on CycloneDX. |
| Cross-check | [Syft](https://github.com/anchore/syft) | The most popular generator, but it finds packages from databases and manifests. An LFS tree has neither, so it would see little. Useful only to compare against. |
| Sign | [cosign](https://github.com/sigstore/cosign), [minisign](https://github.com/jedisct1/minisign) | See Signing below. |

**Prior art.** Yocto's `create-spdx` builds SPDX per recipe and image, and its `cve-check` takes a
CPE product name per recipe (`CVE_PRODUCT`), the same idea as `package_cpe`. Buildroot has
`make legal-info`. Both are worth reading before writing `lib/sbom.sh`.

**Starting set:** `pyspdxtools` and `sbomqs` in step 3, Grype and `sbom-cve-check` for scanning,
ScanCode once for the licence audit. Add Dependency-Track and OpenVEX when there are releases to
keep watching.

## Choices for later

- **CVE matching needs identifiers that scanners know.** purls of type `generic` identify packages
  uniquely but match few vulnerability databases. NVD matches by CPE, so recipes would need a
  `package_cpe` (vendor and product), e.g. `cpe:2.3:a:gnu:bash:5.3`,
  `cpe:2.3:o:linux:linux_kernel:7.3.1`, `cpe:2.3:a:systemd_project:systemd:261.2`. That's about
  twenty recipes for what the systems ship.
- **Suppliers.** NTIA's minimum elements also ask for each component's supplier. A `package_supplier`
  (e.g. `Organization: GNU Project`), or `NOASSERTION` until then.
- **Build tools.** The cross toolchain and the tools that built the system could be added with
  `BUILD_TOOL_OF` relationships. That makes the SBOM describe how the image was built, not only what
  it contains, which is most of what SPDX 3.0's build profile is for.
- **Files.** Per-file SHA-256s of the tree (`hasFiles`) would let a device check its own files
  against the SBOM. That's larger, and best left for after reproducible builds.
- **Signing.** Signing the image's digest and the SBOM together (minisign or cosign) ties the SBOM to
  the image that was published.

**Effort:** steps 1–3 are a few hundred lines (mostly `lib/sbom.sh`) plus a validation run per
platform. CPEs and suppliers are recipe metadata, which can be added package by package.
