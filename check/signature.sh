# What bin/sign, which signs SBOMs, and check/signature, which checks their signatures, share. Both
# source this file with root set to the directory of their checkout.
#
# The signature of an SBOM, <sbom>.sig, is OpenSSH's (ssh-keygen -Y sign), in a namespace of its
# own, so that nothing else that a key signs passes for it. check/allowed_signers has the trusted
# keys, those of lfs-release. A signature vouches for the SBOM, and so for the image whose digest
# the SBOM holds.

readonly signature_namespace=sbom@linux-from-scratch

command -v jq > /dev/null 2>&1 || {
    echo "jq is needed" >&2
    exit 2
}

# Says what is wrong, and stops.
fail() {
    echo "$*" >&2
    exit 1
}

# Takes the current directory off the front of sbom, for short messages: as $PWD names it, perhaps
# through a symlink, or physically, as root does. What remains must not start with a slash, or with
# a dash, as an option does. Where the shell cannot tell the directory, it gives nothing, and `.`
# keeps that from matching every absolute path.
shorten_sbom() {
    for dir in "${PWD-}" "$(pwd -P)"; do
        case $sbom in
            "${dir:-.}"/[!/-]*) sbom=${sbom#"$dir"/} ;;
        esac
    done
}

# Succeeds if the file SIGNATURE is a trusted key's signature of SBOM. Quiet about success, which
# is not yet the image's.
# Usage: verify_signature SBOM SIGNATURE
verify_signature() {
    ssh-keygen -Y verify -f "$root/check/allowed_signers" -I lfs-release \
        -n $signature_namespace -s "$2" < "$1" > /dev/null
}

# Prints what the jq FILTER gives for the package of the image (lib/sbom.sh), if the file SBOM
# holds exactly one.
# Usage: image_property SBOM FILTER
image_property() {
    jq -rs "[.[].packages[] | select(.SPDXID == \"SPDXRef-Image\")]
        | select(length == 1) | .[0] | $2 // empty" "$1"
}

# Stops unless SBOM is named after its image as lib/image.sh names it, and the image, the file of
# that name in its directory, has the digest that SBOM gives. Sets image to the image's path.
# Usage: check_image SBOM
check_image() {
    # jq rules out NULs and newlines, as the shell drops NULs and final newlines from what it reads.
    image=$(image_property "$1" \
        '.packageFileName | strings | select(explode | all(. != 0 and . != 10))')
    # A name with a slash never passes, as the SBOM's file name has none.
    [ -n "$image" ] && [ "${1##*/}" = "${image%.img}.spdx.json" ] \
        || fail "$1: an SBOM is named after its image, and this one names" \
            "${image:-no single image}"
    image=$(dirname "$1")/$image
    [ -f "$image" ] || fail "$1: the image $image is missing"
    digest=$(image_property "$1" \
        '.checksums[]? | select(.algorithm == "SHA256") | .checksumValue')
    # Not in a pipeline, which would hide a failure of shasum.
    sum=$(shasum -a 256 < "$image")
    [ "${sum%% *}" = "$digest" ] || fail "$1: the image $image does not match its digest"
}
