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

get() {
    local url=$1
    local archive=${url##*/}
    # .tgz is a common alternate spelling of .tar.gz with no ".tar."
    # substring to strip via the usual pattern.
    local extracted=${archive%%.tar.*}
    [ "$extracted" != "$archive" ] || extracted=${archive%.tgz}
    mkdir -p $SOURCE_DIR
    [ -f $DOWNLOAD_DIR/$archive ] || wget --no-check-certificate -P $DOWNLOAD_DIR $url
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
