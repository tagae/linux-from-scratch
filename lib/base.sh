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

# Download a URL into a directory.
fetch_url() {
    local url=$1 dest=$2
    wget ${SSL_CERT_FILE:+--ca-certificate="$SSL_CERT_FILE"} -P "$dest" "$url"
}

# Verify a file against an expected algo:hexdigest pair (e.g., sha256:abc...).
# The algorithm prefix selects the checker (sha256 -> sha256sum, etc.).
verify_hash() {
    local file=$1 hash=$2
    local algo=${hash%%:*} digest=${hash#*:}
    printf '%s  %s\n' "$digest" "$file" | "${algo}sum" -c - \
        || bail "Integrity check failed for $file (expected $hash)"
}

get() {
    local url=$1
    # Optional expected source hash, "algo:hexdigest" (package_source_hash).
    local hash=${2:-}
    local archive=${url##*/}
    local extracted=${archive%%.tar.*}
    [ "$extracted" != "$archive" ] || extracted=${archive%.tgz}
    mkdir -p $SOURCE_DIR
    [ -f $DOWNLOAD_DIR/$archive ] || fetch_url "$url" "$DOWNLOAD_DIR"
    [ -z "$hash" ] || verify_hash "$DOWNLOAD_DIR/$archive" "$hash"
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

# Tests whether a capability is enabled.
has_cap() {
    case " ${CAPS:-} " in
        *" $1 "*) ;;
        *) return 1 ;;
    esac
}
