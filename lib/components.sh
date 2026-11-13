# Package Components
# ------------------
#
# Package components are made of a subset of the files installed by the package.
# Those files are moved away from the main package, into the dedicated component.

# Moves aside the development files installed by the package.
move_to_dev_component() {
    local file
    for file; do
        set -- "$@" -o -path "./$file"
        shift
    done
    _move_component_files dev \
        -path ./usr/include -o -path ./usr/share/aclocal \
        -o -path ./usr/lib/pkgconfig -o -path ./usr/share/pkgconfig \
        -o -name '*.a' -o -name '*.la' -o -name '*.o' -o -path './usr/lib/lib*.so' "$@"
}

# Moves aside the documentation installed by the package: whatever it installs under /usr/share/doc,
# its man pages unless `man` is `yes`, and its info pages unless `info` is `yes`. The man pages that
# stay are those of the C locale: the translations, which packages install in a directory for each
# language next to those of the sections (usr/share/man/de), are left out, as is all localisation.
move_to_docs_component() {
    local dir
    for dir in $package_install_dir/usr/share/man/*; do
        [ -d "$dir" ] || continue
        case ${dir##*/} in man[0-9]*) ;; *) rm -rf "$dir" ;; esac
    done

    set -- -path ./usr/share/doc
    [ "${man:-no}" = yes ] || set -- "$@" -o -path ./usr/share/man
    [ "${info:-no}" = yes ] || set -- "$@" -o -path ./usr/share/info
    _move_component_files docs "$@"
}

# Succeeds where the package's documentation is wanted, as man or info pages: for a recipe that has
# to be told to build it (`--$(docs_wanted && echo enable || echo disable)-doc`).
docs_wanted() {
    [ "${man:-no}" = yes ] || [ "${info:-no}" = yes ]
}

# Installs what the package's install set aside for the component being installed.
install_component() {
    local component_dir=$package_work_dir/component/$package_component
    [ -d $component_dir ] || bail "empty $package_name $package_component component"
    cp -av $component_dir/. $package_install_dir/
}

# Moves the files the package installed that match the given find(1) expression aside, for the
# given component, along with the directories that moving them leaves empty.
_move_component_files() {
    local component_dir=$package_work_dir/component/$1
    shift
    rm -rf $component_dir
    ( cd $package_install_dir && find . \( "$@" \) -prune -print ) | while read -r file; do
        mkdir -p $component_dir/${file%/*}
        mv $package_install_dir/$file $component_dir/$file
        ( cd $package_install_dir && rmdir -p ${file%/*} 2>/dev/null ) || :
    done
}
