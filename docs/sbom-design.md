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

Split components that a system doesn't get (`dev`, `debug`, `docs`) stay out. If one is unpacked
into a system by hand, it is a separate archive and can be added the same way.

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

## Choices for later

- **CVE matching needs identifiers that scanners know.** purls of type `generic` identify packages
  uniquely but match few vulnerability databases. NVD matches by CPE, so recipes would need a
  `package_cpe` (vendor and product), e.g. `cpe:2.3:a:gnu:bash:5.3`,
  `cpe:2.3:o:linux:linux_kernel:7.1.2`, `cpe:2.3:a:systemd_project:systemd:260.2`. That's about
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
