# Split Components
# ----------------
#
# A package's install can set some of the files it installed aside for one of its split components,
# which install them only where they are wanted:
#
# - dev: what developing with the package needs (headers, static libraries, pkg-config files...),
#   for build trees rather than systems.
# - debug: the debugging information of its programs and libraries, for debuggers, which look for it
#   under /usr/lib/debug. The programs and libraries are left stripped, each linked by name and
#   checksum to its debugging information.
# - docs: its documentation (man and info pages, and whatever it installs under /usr/share/doc), for
#   systems that want it.

# Moves the development files the package installed aside, for its dev component: those that any
# package installs, plus the given ones (paths relative to the install root), which only the package
# can tell apart.
split_dev_files() {
    local file
    for file; do
        set -- "$@" -o -path "./$file"
        shift
    done
    _split_files dev \
        -path ./usr/include -o -path ./usr/share/aclocal \
        -o -path ./usr/lib/pkgconfig -o -path ./usr/share/pkgconfig \
        -o -name '*.a' -o -name '*.la' -o -name '*.o' -o -path './usr/lib/lib*.so' "$@"
}

# Moves the documentation the package installed aside, for its docs component.
split_docs() {
    _split_files docs -path ./usr/share/man -o -path ./usr/share/info -o -path ./usr/share/doc
}

# Moves the debugging information out of the programs and libraries the package installed, for its
# debug component.
split_debug_info() {
    local split_dir=$package_work_dir/split/debug
    rm -rf $split_dir
    find $package_install_dir -type f | while read -r file; do
        # Programs and shared libraries only, not objects, static libraries or kernel modules.
        ${host:+$host-}readelf -h $file 2>/dev/null | grep -qE 'Type: +(EXEC|DYN)' || continue
        local debug_file=$split_dir/usr/lib/debug${file#"$package_install_dir"}.debug
        mkdir -p ${debug_file%/*}
        ${host:+$host-}objcopy --only-keep-debug $file $debug_file
        ${host:+$host-}objcopy --strip-unneeded --add-gnu-debuglink=$debug_file $file
    done
}

# Installs what the package's install set aside for the component being installed. The install of
# a split component.
install_split() {
    local split_dir=$package_work_dir/split/$package_component
    [ -d $split_dir ] || bail "$package_name set nothing aside for its $package_component component"
    cp -av $split_dir/. $package_install_dir/
}

# Moves the files the package installed that match the given find(1) expression aside, for the
# given component, along with the directories that moving them leaves empty.
_split_files() {
    local split_dir=$package_work_dir/split/$1
    shift
    rm -rf $split_dir
    ( cd $package_install_dir && find . \( "$@" \) -prune -print ) | while read -r file; do
        mkdir -p $split_dir/${file%/*}
        mv $package_install_dir/$file $split_dir/$file
        ( cd $package_install_dir && rmdir -p ${file%/*} 2>/dev/null ) || :
    done
}
