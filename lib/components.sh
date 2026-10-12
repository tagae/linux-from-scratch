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

# Moves aside the documentation installed by the package.
move_to_docs_component() {
    _move_component_files docs -path ./usr/share/man -o -path ./usr/share/info -o -path ./usr/share/doc
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
