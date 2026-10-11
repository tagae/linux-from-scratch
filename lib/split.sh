# Split Components
# ----------------
#
# A package's install can set some of the files it installed aside for one of its split components,
# which install them only where they are wanted:
#
# - dev: what compiling against the package needs (headers, static libraries, pkg-config files...),
#   for build trees rather than systems.
# - debug: the debugging information of its programs and libraries, for debuggers, which look for it
#   under /usr/lib/debug. The programs and libraries are left stripped, each linked by name and
#   checksum to its debugging information.

# Moves the development files the package installed aside, for its dev component.
split_dev_files() {
    local split_dir=$package_work_dir/split/dev
    rm -rf $split_dir
    (
        cd $package_install_dir
        find . \( -path ./usr/include -o -path ./usr/share/aclocal \
               -o -path ./usr/lib/pkgconfig -o -path ./usr/share/pkgconfig \
               -o -name '*.a' -o -name '*.la' -o -name '*.o' -o -path './usr/lib/lib*.so' \) \
             -prune -print
    ) | while read -r file; do
        mkdir -p $split_dir/${file%/*}
        mv $package_install_dir/$file $split_dir/$file
    done
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
