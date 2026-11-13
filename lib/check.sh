# Checks
# ------
#
# `lfs check PACKAGE` examines what a package put in the system, after the system is built (the
# archive says which files are the package's, the install tree is where they run).
#
# Interpreters: every program has its interpreter in the system, the one that a script's first line
# names, or the dynamic linker that an executable asks for. The kernel runs neither, and the shell
# reports the program as not found, rather than what is missing.

lfs_check_package() {
    local install_dir=$INSTALL_DIR/$PROFILE
    [ -d "$install_dir" ] || bail "Install directory not found: $install_dir: build the system"
    local archive
    archive=$(lfs_package_archive "$1")
    [ -s "$archive" ] || bail "No archive of $1: $archive"

    local missing=$(_programs_without_interpreter $install_dir "$archive")
    [ -z "$missing" ] || bail "Programs of $1 without their interpreter in the system:
$missing"
}

# Prints the programs in the archive that lack their interpreter in the system at ROOT, with the
# interpreter that is missing.
_programs_without_interpreter() {
    local root=$1 elf=$(printf '\177ELF') path file magic interpreter
    tar -tf "$2" | while read -r path; do
        file=$root/${path#./}
        [ -f "$file" ] && [ ! -L "$file" ] && [ -x "$file" ] || continue
        magic=$(head -c 4 "$file" | tr -d '\000')
        case $magic in
            '#!'*) interpreter=$(_script_interpreter "$file") ;;
            "$elf") interpreter=$(_dynamic_linker "$file") ;;
            *) continue ;;
        esac
        [ -z "$interpreter" ] || _system_has_file "$root" "$interpreter" \
            || echo "  ${file#"$root"}: $interpreter"
    done
}

# Prints the interpreter that the script's first line names: the program that `env` runs, when it
# does.
_script_interpreter() {
    set -f
    set -- $(head -n 1 "$1" | cut -c 3-)
    set +f
    case ${1:-} in
        */env)
            shift
            while [ $# -gt 0 ]; do
                case $1 in -*|*=*) shift ;; *) break ;; esac
            done
            [ $# -eq 0 ] || echo /usr/bin/$1
            ;;
        *) echo ${1:-} ;;
    esac
}

# Prints the dynamic linker that the executable asks for, if it does.
_dynamic_linker() {
    $target_triplet-readelf -l "$1" \
        | sed -n 's/.*Requesting program interpreter: \(.*\)\]/\1/p'
}

# Whether PATH, an absolute path, names a file in the system at ROOT. Links are followed within the
# system, whose absolute ones the build machine would follow to its own files.
_system_has_file() {
    local root=$1 path=$2 depth=0 link
    while [ -L "$root$path" ]; do
        depth=$((depth + 1))
        [ $depth -le 20 ] || return 1
        link=$(readlink "$root$path")
        case $link in
            /*) path=$link ;;
            *) path=${path%/*}/$link ;;
        esac
    done
    [ -f "$root$path" ]
}
