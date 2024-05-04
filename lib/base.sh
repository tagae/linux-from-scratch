die() {
    local exit_code=$1
    shift
    echo "$@" >&2
    exit $exit_code
}

bail() {
    die 1 "$@"
}

todo() {
    bail 'Not implemented yet'
}

usage() {
    bail "Usage: $(basename "$0") $@"
}

stage() {
    printf "\n%s[ %s ]\n" '---' "$1"
}

get() {
    local url=$1
    local archive=${url##*/}
    mkdir -p $SOURCE_DIR
    [ -f $DOWNLOAD_DIR/$archive ] || wget --no-check-certificate -P $DOWNLOAD_DIR $url
    [ -d $SOURCE_DIR/${archive%%.tar.*} ] || tar xf $DOWNLOAD_DIR/$archive -C $SOURCE_DIR
}

git_default_branch() {
    local url="$1"
    git ls-remote --symref $url HEAD | awk '/^ref:/ {sub("refs/heads/", "", $2); print $2}'
}

git_checkout() {
    local url="$1"
    local branch="$2"
    local dest="$3"
    ! [ -d $dest/.git ] || return 0
    mkdir -p $(dirname $dest)
    git clone --branch $branch --depth 1 $url $dest
}

# older_than() {
#     FILE="$1"
#     MAX_AGE="$2"
#     test -e "$FILE" || return true
#     LAST_UPDATE=$(date -r "$FILE" +%s)
#     NOW=$(date +%s)
#     $(( LAST_UPDATE + MAX_AGE < NOW ))
# }
