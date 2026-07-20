die() {
    local exit_code=$1
    shift
    echo "$@" >&2
    exit $exit_code
}

bail() {
    die 1 "$@"
}

usage() {
    bail "Usage: $(basename "$0") $@"
}

stage() {
    if [ -t 1 ]; then
        echo
        echo "---[ $@ ]"
    fi
}

# Download a URL into a directory, verifying the server's TLS certificate
# against $SSL_CERT_FILE when that bundle exists, and falling back to
# unverified transport otherwise. The fallback is safe because every source
# is integrity-checked by package_source_sha256 regardless — the CA bundle
# only adds channel authentication (defence in depth, fail-fast on a MITM).
# It is a fallback specifically to break the bootstrap: the ca-certificates
# package's own hash-pinned sources are fetched before that bundle exists.
fetch_url() {
    local url=$1 dest=$2
    if [ -s "${SSL_CERT_FILE:-/dev/null}" ]; then
        wget --ca-certificate="$SSL_CERT_FILE" -P "$dest" "$url"
    else
        wget --no-check-certificate -P "$dest" "$url"
    fi
}

get() {
    local url=$1
    # Optional expected SHA-256 of the archive (package_source_sha256).
    local sha256=${2:-}
    local archive=${url##*/}
    # .tgz is a common alternate spelling of .tar.gz with no ".tar."
    # substring to strip via the usual pattern.
    local extracted=${archive%%.tar.*}
    [ "$extracted" != "$archive" ] || extracted=${archive%.tgz}
    mkdir -p $SOURCE_DIR
    [ -f $DOWNLOAD_DIR/$archive ] || fetch_url "$url" "$DOWNLOAD_DIR"
    # Verify integrity before unpacking, whenever an expected hash is given.
    # Runs on the on-disk archive whether just downloaded or cached from a
    # previous run, so a corrupted/tampered cache is caught too. (fetch is
    # stamped via _once, so this happens once per package, not every build.)
    if [ -n "$sha256" ]; then
        printf '%s  %s\n' "$sha256" "$DOWNLOAD_DIR/$archive" | sha256sum -c - \
            || bail "Integrity check failed for $archive (expected sha256 $sha256)"
    fi
    [ -d $SOURCE_DIR/$extracted ] || tar xf $DOWNLOAD_DIR/$archive -C $SOURCE_DIR
}

git_default_branch() {
    local url="$1" branch_file=$(mktemp -t git-default-branch-XXXXXX)
    git ls-remote --symref $url HEAD > $branch_file
    awk '/^ref:/ {sub("refs/heads/", "", $2); print $2}' < $branch_file
}

git_checkout() {
    local url="$1" branch="$2" dest="$3"
    ! [ -d $dest/.git ] || return 0
    mkdir -p $(dirname $dest)
    git clone --branch $branch --depth 1 $url $dest
}
