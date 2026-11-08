# Software Bill of Materials
# --------------------------
#
# An image gets an SPDX 2.3 document in JSON next to it, <image>.spdx.json. It names what the image
# holds: the archive of every package that the system build installed, with its digest and licence,
# and the upstream source that the archive was built from, with the source's URL and digest.
# docs/sbom-design.md has the reasoning.
#
# The system build lists the packages as it installs them (lfs_sbom_record_package), and the image
# build writes the document from that list and the image's digest (lfs_sbom_document). A line of the
# list holds, separated by tabs: the archive's name and SHA-256, and the package's name, version,
# licence, source, source digest and description. Only the description may be empty, as `read` drops
# an empty field that is not the last; a package without a source or digest has `none`, as in the
# recipes.
#
# A licence that SPDX does not list is a LicenseRef-<name>, whose text is in the files directory of
# the package that declares it, as package/<package>/LicenseRef-<name>.txt.

# The list of the packages of the system being built.
_sbom_packages_file() {
    echo $WORK_DIR/sbom/$SYSTEM_KEY
}

# Empties the list, for a system build that starts anew.
lfs_sbom_start() {
    mkdir -p $WORK_DIR/sbom
    : > $(_sbom_packages_file)
}

# Adds a package that the system build has installed into the system to the list. The archive's
# digest is the one that the install has just checked.
lfs_sbom_record_package() (
    lfs_source_package "$1"
    local archive=$(archive_filename)
    printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' \
        "$package_archive" "$(cut -d' ' -f1 < $archive.sha256)" \
        "$package_name" "$package_version" "$package_license" \
        "${package_source:-none}" "${package_source_hash:-none}" "${package_description:-}" \
        >> $(_sbom_packages_file)
)

# Prints the document of the image with the given file name and SHA-256, for the system just built.
lfs_sbom_document() {
    local name=$1 digest=$2
    local packages=$(_sbom_packages_file)
    local tab=$(printf '\t')
    local archive archive_digest package version license source source_hash description
    local id refs ref seen=

    [ -s $packages ] || bail "No list of packages at $packages: build the system again"

    cat <<EOF
{
  "spdxVersion": "SPDX-2.3",
  "dataLicense": "CC0-1.0",
  "SPDXID": "SPDXRef-DOCUMENT",
  "name": $(_sbom_string "$SYSTEM_KEY"),
  "documentNamespace": $(_sbom_string "https://spdx.org/spdxdocs/lfs-$SYSTEM_KEY-$digest"),
  "creationInfo": {
    "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
    "creators": [$(_sbom_string "Tool: lfs${LFS_RELEASE:+-$LFS_RELEASE}")]
  },
  "packages": [
EOF
    _sbom_image_package "$name" "$digest"
    while IFS=$tab read -r archive archive_digest package version license source source_hash description; do
        printf ',\n'
        _sbom_archive_package "$archive" "$archive_digest" "$package" "$version" "$license" \
            "$source" "$source_hash" "$description"
    done < $packages
    # Archives built from the same source share it.
    while IFS=$tab read -r archive archive_digest package version license source source_hash description; do
        [ "$source" != none ] || continue
        id=$(_sbom_source_id "$package" "$version")
        case " $seen " in *" $id "*) continue ;; esac
        seen="$seen $id"
        printf ',\n'
        _sbom_source_package "$package" "$version" "$license" "$source" "$source_hash"
    done < $packages

    printf '\n  ],\n  "relationships": [\n'
    printf '    { "spdxElementId": "SPDXRef-DOCUMENT", "relationshipType": "DESCRIBES", '
    printf '"relatedSpdxElement": "SPDXRef-Image" }'
    while IFS=$tab read -r archive archive_digest package version license source source_hash description; do
        id=$(_sbom_archive_id "$archive")
        printf ',\n    { "spdxElementId": "SPDXRef-Image", "relationshipType": "CONTAINS", '
        printf '"relatedSpdxElement": "%s" }' "$id"
        [ "$source" != none ] || continue
        printf ',\n    { "spdxElementId": "%s", "relationshipType": "GENERATED_FROM", ' "$id"
        printf '"relatedSpdxElement": "%s" }' "$(_sbom_source_id "$package" "$version")"
    done < $packages
    printf '\n  ]'

    refs=$(_sbom_license_refs $packages)
    if [ -n "$refs" ]; then
        printf ',\n  "hasExtractedLicensingInfos": [\n'
        seen=
        while read -r ref package; do
            [ -z "$seen" ] || printf ',\n'
            seen=yes
            [ -f $package_dir/$package/$ref.txt ] \
                || bail "No text of $ref: $package_dir/$package/$ref.txt"
            printf '    {\n      "licenseId": "%s",\n      "name": "%s",\n' "$ref" "$ref"
            printf '      "extractedText": %s\n    }' \
                "$(_sbom_string "$(cat $package_dir/$package/$ref.txt)")"
        done <<EOF
$refs
EOF
        printf '\n  ]'
    fi
    printf '\n}\n'
}

# Prints the image as the package that the document describes.
_sbom_image_package() {
    local version_line=
    [ -z "${LFS_RELEASE:-}" ] || version_line="\"versionInfo\": $(_sbom_string "$LFS_RELEASE"),"
    cat <<EOF
    {
      "SPDXID": "SPDXRef-Image",
      "name": $(_sbom_string "$SYSTEM_KEY"),
      $version_line
      "packageFileName": $(_sbom_string "$1"),
      $(_sbom_checksums sha256:$2)
      "downloadLocation": "NOASSERTION",
      "filesAnalyzed": false,
      "licenseConcluded": "NOASSERTION",
      "licenseDeclared": "NOASSERTION",
      "copyrightText": "NOASSERTION",
      "primaryPackagePurpose": "OPERATING-SYSTEM"
    }
EOF
}

# Prints an archive that the system holds as a package of the document, named by its package URL.
_sbom_archive_package() {
    local archive=$1 digest=$2 package=$3 version=$4 license=$5 source=$6 source_hash=$7
    local description_line=
    [ -z "$8" ] || description_line="\"description\": $(_sbom_string "$8"),"
    cat <<EOF
    {
      "SPDXID": "$(_sbom_archive_id "$archive")",
      "name": $(_sbom_string "$package"),
      "versionInfo": $(_sbom_string "$version"),
      "packageFileName": $(_sbom_string "$archive"),
      $(_sbom_checksums sha256:$digest)
      "downloadLocation": "NOASSERTION",
      "filesAnalyzed": false,
      "licenseConcluded": "NOASSERTION",
      "licenseDeclared": $(_sbom_string "$license"),
      "copyrightText": "NOASSERTION",
      $description_line
      "externalRefs": [{
        "referenceCategory": "PACKAGE-MANAGER",
        "referenceType": "purl",
        "referenceLocator": $(_sbom_string "$(_sbom_purl "$package" "$version" "$source" "$source_hash")")
      }]
    }
EOF
}

# Prints the upstream source of one or more archives.
_sbom_source_package() {
    local package=$1 version=$2 license=$3 source=$4 source_hash=$5
    cat <<EOF
    {
      "SPDXID": "$(_sbom_source_id "$package" "$version")",
      "name": $(_sbom_string "$package"),
      "versionInfo": $(_sbom_string "$version"),
      "packageFileName": $(_sbom_string "${source##*/}"),
      $(_sbom_checksums "$source_hash")
      "downloadLocation": $(_sbom_string "$source"),
      "filesAnalyzed": false,
      "licenseConcluded": "NOASSERTION",
      "licenseDeclared": $(_sbom_string "$license"),
      "copyrightText": "NOASSERTION",
      "primaryPackagePurpose": "SOURCE"
    }
EOF
}

# Prints a `<LicenseRef> <package>` line for each LicenseRef of the packages' licences, once.
_sbom_license_refs() {
    local tab=$(printf '\t')
    local archive archive_digest package version license rest word ref
    while IFS=$tab read -r archive archive_digest package version license rest; do
        for word in $license; do
            ref=${word#\(}
            ref=${ref%\)}
            case $ref in
                LicenseRef-*) printf '%s %s\n' "$ref" "$package" ;;
            esac
        done
    done < $1 | sort -u -k1,1
}

# Prints the identifier of an archive's package in the document, and of a source's.
_sbom_archive_id() {
    echo SPDXRef-Package-$(_sbom_id "${1%.tar.xz}")
}

_sbom_source_id() {
    echo SPDXRef-Source-$(_sbom_id "$1-$2")
}

# Identifiers have letters, digits, dots and hyphens.
_sbom_id() {
    printf '%s' "$1" | tr -c 'A-Za-z0-9.-' '-'
}

# Prints the identifier of a package in the form of a package URL. The type is `generic`: the
# recipes' names are upstream's, which no ecosystem's registry knows by them.
_sbom_purl() {
    local purl=pkg:generic/$1@$2
    if [ "$3" != none ]; then
        purl="$purl?download_url=$3"
        [ "$4" = none ] || purl="$purl&checksum=$4"
    fi
    echo "$purl"
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
