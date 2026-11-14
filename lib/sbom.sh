# Software Bill of Materials
# --------------------------
#
# An image gets an SPDX 2.3 document in JSON next to it, <image>.spdx.json. It names the upstream
# packages that the image holds, each with its version, licence, and the URL and digest of the
# source it was built from, and with the identifiers that vulnerability scanners match: its CPE, as
# the NVD names it, and its package URL. docs/sbom-design.md has the reasoning.
#
# The system build lists the packages as it installs them (lfs_sbom_record_package), and the image
# build writes the document from that list and the image's digest (lfs_sbom_document). A package
# that the system installs twice is in the document once. A package without a source holds this
# project's own files, which the image stands for: it is not in the document.
#
# A line of the list holds, separated by tabs: the package's recipe, and its name, version, licence,
# source, source digest, CPEs and description. Only the description may be empty, as `read` drops an
# empty field that is not the last; a package without a digest or a CPE has `none`.
#
# A CPE is part:vendor:product:version, which the document completes. By default, the product is the
# package's name, the version its own, and the vendor the owner of the source's project on GitHub or
# GitLab, or else the name of the site that serves the source (gnu, for ftp.gnu.org). A recipe whose
# package the NVD names otherwise sets package_cpe to its CPEs, or to `none` where the NVD has
# none. The document gives a package the version of its first CPE: scanners compare that version
# with the vulnerable ones. A package from PyPI has no CPE: it is named after its PyPI project, and
# its package URL is a PyPI one, which scanners match against Python's advisories.
#
# A package's concluded licence is its declared one: the recipes take package_license from the
# source's own licence files. Nothing gathers the copyright notices of the sources, so those stay
# NOASSERTION; the image's own is this project's.
#
# A licence that SPDX does not list is a LicenseRef-<name>, whose text is in the files directory of
# the package that declares it, as package/<package>/LicenseRef-<name>.txt.

readonly sbom_pypi_sources=https://files.pythonhosted.org/packages/source

# The copyright of this project's own files, which the image stands for (LICENSE's first line; the
# containers do not have the file).
readonly sbom_copyright='Copyright (c) 2024 Sebastián González Montesinos'

# The list of the packages of the system being built.
_sbom_packages_file() {
    echo $WORK_DIR/sbom/$PROFILE
}

# Empties the list, for a system build that starts anew.
lfs_sbom_start() {
    mkdir -p $WORK_DIR/sbom
    : > $(_sbom_packages_file)
}

# Adds a package that the system build has installed into the system to the list.
lfs_sbom_record_package() (
    lfs_source_package "$1"
    [ "${package_source:-none}" != none ] || return 0
    local name=$package_name version=$package_version cpes
    case $package_source in
        $sbom_pypi_sources/*)
            name=${package_source#$sbom_pypi_sources/?/}
            name=${name%%/*}
            cpes=none
            ;;
        *)
            cpes=${package_cpe:-$(_sbom_default_cpe)}
            ;;
    esac
    [ "$cpes" = none ] || version=$(echo "${cpes%% *}" | cut -d: -f4)
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$package_name" "$name" "$version" "$package_license" \
        "$package_source" "${package_source_hash:-none}" "$cpes" "${package_description:-}" \
        >> $(_sbom_packages_file)
)

# Prints the CPE that the package of the sourced recipe has by default.
_sbom_default_cpe() {
    local site=${package_source#*://} vendor
    case $site in
        github.com/*|gitlab.com/*)
            vendor=${site#*/}
            vendor=${vendor%%/*}
            ;;
        *)
            vendor=${site%%/*}
            vendor=${vendor%.*}
            vendor=${vendor##*.}
            ;;
    esac
    echo a:$(printf '%s' "$vendor" | tr A-Z a-z):$package_name:$package_version
}

# Prints the document of the image with the given file name and SHA-256, for the system just built.
lfs_sbom_document() {
    local name=$1 digest=$2
    local packages=$(_sbom_packages_file)
    local tab=$(printf '\t')
    local recipe package version license source source_hash cpes description
    local id refs ref seen=

    [ -s $packages ] || bail "No list of packages at $packages: build the system again"

    cat <<EOF
{
  "spdxVersion": "SPDX-2.3",
  "dataLicense": "CC0-1.0",
  "SPDXID": "SPDXRef-DOCUMENT",
  "name": $(_sbom_string "$PROFILE"),
  "documentNamespace": $(_sbom_string "https://spdx.org/spdxdocs/lfs-$PROFILE-$digest"),
  "creationInfo": {
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "creators": [$(_sbom_string "Tool: lfs${LFS_RELEASE:+-$LFS_RELEASE}")]
  },
  "packages": [
EOF
    _sbom_image_package "$name" "$digest"
    while IFS=$tab read -r recipe package version license source source_hash cpes description; do
        id=$(_sbom_package_id "$package" "$version")
        case " $seen " in *" $id "*) continue ;; esac
        seen="$seen $id"
        printf ',\n'
        _sbom_package "$id" "$package" "$version" "$license" "$source" "$source_hash" "$cpes" \
            "$description"
    done < $packages

    printf '\n  ],\n  "relationships": [\n'
    printf '    { "spdxElementId": "SPDXRef-DOCUMENT", "relationshipType": "DESCRIBES", '
    printf '"relatedSpdxElement": "SPDXRef-Image" }'
    for id in $seen; do
        printf ',\n    { "spdxElementId": "SPDXRef-Image", "relationshipType": "CONTAINS", '
        printf '"relatedSpdxElement": "%s" }' "$id"
    done
    printf '\n  ]'

    refs=$(_sbom_license_refs $packages)
    if [ -n "$refs" ]; then
        printf ',\n  "hasExtractedLicensingInfos": [\n'
        seen=
        while read -r ref recipe; do
            [ -z "$seen" ] || printf ',\n'
            seen=yes
            [ -f $package_dir/$recipe/$ref.txt ] \
                || bail "No text of $ref: $package_dir/$recipe/$ref.txt"
            printf '    {\n      "licenseId": "%s",\n      "name": "%s",\n' "$ref" "$ref"
            printf '      "extractedText": %s\n    }' \
                "$(_sbom_string "$(cat $package_dir/$recipe/$ref.txt)")"
        done <<EOF
$refs
EOF
        printf '\n  ]'
    fi
    printf '\n}\n'
}

# Prints the line that tells the release the image is made as, if it is known: the version of this
# project's tree, which names its commit and whether files differ from it.
_sbom_release_line() {
    [ -z "${LFS_RELEASE:-}" ] || echo "\"versionInfo\": $(_sbom_string "$LFS_RELEASE"),"
}

# Whether the SBOM in FILE tells the release that is current, in which case the image is the one
# that this project makes, and a new commit makes another. Without a release, nothing tells.
lfs_sbom_has_release() {
    local line=$(_sbom_release_line)
    [ -z "$line" ] || grep -qF -- "$line" "$1"
}

# Prints the image as the package that the document describes.
_sbom_image_package() {
    cat <<EOF
    {
      "SPDXID": "SPDXRef-Image",
      "name": $(_sbom_string "$PROFILE"),
      $(_sbom_release_line)
      "packageFileName": $(_sbom_string "$1"),
      $(_sbom_checksums sha256:$2)
      "downloadLocation": "NONE",
      "filesAnalyzed": false,
      "licenseConcluded": "NOASSERTION",
      "licenseDeclared": "NOASSERTION",
      "copyrightText": $(_sbom_string "$sbom_copyright"),
      "primaryPackagePurpose": "OPERATING-SYSTEM"
    }
EOF
}

# Prints a package that the image holds, as its source names it, with its package URL and CPEs.
_sbom_package() {
    local id=$1 package=$2 version=$3 license=$4 source=$5 source_hash=$6 cpes=$7 cpe
    local description_line=
    [ -z "$8" ] || description_line="\"description\": $(_sbom_string "$8"),"
    cat <<EOF
    {
      "SPDXID": "$id",
      "name": $(_sbom_string "$package"),
      "versionInfo": $(_sbom_string "$version"),
      "packageFileName": $(_sbom_string "${source##*/}"),
      $(_sbom_checksums "$source_hash")
      "downloadLocation": $(_sbom_string "$source"),
      "filesAnalyzed": false,
      "licenseConcluded": $(_sbom_string "$license"),
      "licenseDeclared": $(_sbom_string "$license"),
      "copyrightText": "NOASSERTION",
      $description_line
      "externalRefs": [{
        "referenceCategory": "PACKAGE-MANAGER",
        "referenceType": "purl",
        "referenceLocator": $(_sbom_string "$(_sbom_purl "$package" "$version" "$source" "$source_hash")")
EOF
    [ "$cpes" = none ] || for cpe in $cpes; do
        printf '      }, {\n        "referenceCategory": "SECURITY",\n'
        printf '        "referenceType": "cpe23Type",\n'
        printf '        "referenceLocator": "cpe:2.3:%s:*:*:*:*:*:*:*"\n' "$cpe"
    done
    printf '      }]\n    }'
}

# Prints a `<LicenseRef> <recipe>` line for each LicenseRef of the packages' licences, once.
_sbom_license_refs() {
    local tab=$(printf '\t')
    local recipe package version license rest word ref
    while IFS=$tab read -r recipe package version license rest; do
        for word in $license; do
            ref=${word#\(}
            ref=${ref%\)}
            case $ref in
                LicenseRef-*) printf '%s %s\n' "$ref" "$recipe" ;;
            esac
        done
    done < $1 | sort -u -k1,1
}

# Prints the identifier of a package in the document: letters, digits, dots and hyphens.
_sbom_package_id() {
    echo SPDXRef-Package-$(printf '%s' "$1-$2" | tr -c 'A-Za-z0-9.-' '-')
}

# Prints the package URL of a package: a PyPI one for a package from PyPI, else of type `generic`,
# which identifies the package by its source.
_sbom_purl() {
    case $3 in
        $sbom_pypi_sources/*) echo "pkg:pypi/$1@$2" ;;
        *)
            local purl="pkg:generic/$1@$2?download_url=$3"
            [ "$4" = none ] || purl="$purl&checksum=$4"
            echo "$purl"
            ;;
    esac
}

# Prints the checksums property of a digest given as algo:hexdigest, unless it is `none`.
_sbom_checksums() {
    [ "$1" != none ] || return 0
    printf '"checksums": [{ "algorithm": "%s", "checksumValue": "%s" }],' \
        "$(printf '%s' "${1%%:*}" | tr a-z A-Z)" "${1#*:}"
}

# Prints its argument as a JSON string.
_sbom_string() {
    local tab=$(printf '\t')
    printf '"%s"' "$(printf '%s\n' "$1" \
        | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/$tab/\\\\t/g" \
        | awk 'NR > 1 { printf "\\n" } { printf "%s", $0 }')"
}
