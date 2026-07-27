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

# Download a URL into a directory, always verifying the server's TLS
# certificate against $SSL_CERT_FILE — never falling back to unverified
# transport. That bundle is guaranteed present: the bootstrap phase runs in
# Debian (which ships one at the standard path), and the scratch phase gets
# one seeded into $TOOL_DIR at the end of bootstrap_tools (see there) before
# its first download, later overwritten by the ca-certificates package's own
# from-scratch bundle. If it is somehow missing or empty we refuse to
# download rather than fetch over an unauthenticated channel. (Integrity is
# still additionally guaranteed by package_source_hash in get() — defence
# in depth against a trusted-but-compromised mirror — but authentication is
# no longer optional.)
fetch_url() {
    local url=$1 dest=$2
    [ -s "${SSL_CERT_FILE:-/dev/null}" ] \
        || bail "No CA bundle at '${SSL_CERT_FILE:-}': refusing to fetch $url over unverified TLS"
    wget --ca-certificate="$SSL_CERT_FILE" -P "$dest" "$url"
}

# Verify a file against an expected hash written "algo:hexdigest"
# (package_source_hash), e.g. sha256:abc… — the algorithm prefix selects the
# coreutils checker (sha256 -> sha256sum, sha512 -> sha512sum, …), so a pin
# can move to a stronger digest per package with no change here. Bails on
# mismatch. (SRI/Nix-style; a bare digest with no "algo:" prefix fails, since
# "<digest>sum" is not a command — every pin must name its algorithm.)
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

# Is the running system ITSELF an LFS build host — i.e. a booted LFS
# guest? True when the OS's own compiler is our lineage (vendor triple
# "-scratch-", something no seed container's compiler has) AND it is
# genuinely the OS's own: the scratch container sees the same compiler
# only because the tools volume is aliased at /usr, in which case
# TOOL_DIR's own copy is that same file — whereas on a booted guest,
# TOOL_DIR holds only per-target cross tools (bin/$target-*), never a
# native usr/bin/gcc. Replaces the old LFS_PHASE=guest flag with
# detection (docs/design/build-phases.md).
_os_is_build_host() {
    gcc -dumpmachine 2>/dev/null | grep -q -- -scratch- \
        && [ ! -e "$TOOL_DIR/usr/bin/gcc" ]
}

# Is the capability named $1 enabled — present in the space-separated,
# normalized $CAPS list (see lfs's Capabilities section)? The one shared
# guard behind every capability conditional (lfs's qemu case, the
# bootable-* umbrellas' optional members). Exact-word match: the padded
# spaces mean "net" never matches inside "network". Unset/empty CAPS
# enables nothing.
has_cap() {
    case " ${CAPS:-} " in
        *" $1 "*) ;;
        *) return 1 ;;
    esac
}
