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
    bail "Usage: $(basename "$0") $*"
}

stage() {
    if [ -t 1 ]; then
        echo
        echo "---[ $* ]"
    fi
}

# Download a URL into a directory.
fetch_url() {
    local url=$1 dest=$2 tmp
    mkdir -p "$dest"
    # The download has a name of its own until it is complete: builds that run at once share
    # downloads, and one would take another's partial file for the whole.
    tmp=$(mktemp "$dest/${url##*/}.XXXXXX.tmp")
    wget -O "$tmp" "$url" && chmod 644 "$tmp" && mv "$tmp" "$dest/${url##*/}" || {
        rm -f "$tmp"
        return 1
    }
}

# Verify a file against an expected algo:hexdigest pair (e.g., sha256:abc...).
# The algorithm prefix selects the checker (sha256 -> sha256sum, etc.).
verify_hash() {
    local file=$1 hash=$2
    local algo=${hash%%:*} digest=${hash#*:}
    printf '%s  %s\n' "$digest" "$file" | "${algo}sum" -c - \
        || bail "Integrity check failed for $file (expected $hash)"
}

# Unpacks an archive into a directory.
unpack() {
    tar xf "$1" -C "$2"
}

# Downloads an archive and unpacks it.
get() {
    local url=$1
    # Optional expected source hash, "algo:hexdigest" (package_source_hash).
    local hash=${2:-}
    local dir=$package_category
    local archive=${url##*/}
    local extracted=${archive%%.tar.*}
    [ "$extracted" != "$archive" ] || extracted=${archive%.tgz}
    mkdir -p $LFS_SOURCE_DIR/$dir
    [ -f $LFS_DOWNLOAD_DIR/$dir/$archive ] || fetch_url "$url" "$LFS_DOWNLOAD_DIR/$dir"
    [ -z "$hash" ] || verify_hash "$LFS_DOWNLOAD_DIR/$dir/$archive" "$hash"
    [ -d $LFS_SOURCE_DIR/$dir/$extracted ] \
        || unpack $LFS_DOWNLOAD_DIR/$dir/$archive $LFS_SOURCE_DIR/$dir
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
