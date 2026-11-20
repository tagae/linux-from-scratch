: ${package_version:=1.38.0}
: ${package_source:=https://busybox.net/downloads/busybox-$package_version.tar.bz2}
: ${package_source_hash:=sha256:34f9ea6ff8636f2c9241153b9114eefa9e65674a45318ae1ef95bb5f31c53bb2}
: ${package_description:=Multi-call binary of small Unix utilities: init, shell, login and core utilities.}
# The GPL is the project's (LICENSE: version 2 only). The BSD-3-Clause files are libbb's own code
# (correct_password, run_shell, change_identity, setup_environment), which the applets link.
: ${package_license:=GPL-2.0-only AND BSD-3-Clause}

# The applets are those of the categories that `applets` names (a category is a directory of
# BusyBox's source): package/busybox/<category>.config, with the applets of the category that the
# system's kernels can serve.

prepare() {
    case $package_component in
        busybox)
            # BusyBox builds in its source tree, which holds the object files and the configuration:
            # the source is copied into the build directory, which an earlier run may have left
            # configured.
            find . -mindepth 1 -delete
            cp -a "$package_source_dir/." .

            # A misspelled category in a profile fails here, before a BusyBox without its applets is built.
            local category
            for category in ${applets:-}; do
                [ -f $package_files_dir/$category.config ] \
                    || bail "Unknown BusyBox applet category '$category'"
            done

            # The configuration starts from allnoconfig, and adds base.config and the file of each
            # category in `applets`. allnoconfig writes a line for every option, and kconfig keeps
            # the first value of an option, so the options of the files replace those lines before
            # they are appended.
            local fragment
            fragment=$(
                cat $package_files_dir/base.config
                for category in ${applets:-}; do
                    cat $package_files_dir/$category.config
                done
            )
            make ${target_triplet:+CROSS_COMPILE=$target_triplet-} allnoconfig
            for option in $(printf '%s\n' "$fragment" | grep -o 'CONFIG_[A-Z0-9_]*' | sort -u)
            do
                grep -E -v "^(# )?$option(=| is not set)" .config > .config.new
                mv .config.new .config
            done
            printf '%s\n' "$fragment" >> .config
            make silentoldconfig
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        busybox)
            make ${target_triplet:+CROSS_COMPILE=$target_triplet-}
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        busybox)
            # The merged-usr layout has /bin and /sbin link to usr/bin and usr/sbin, so the applets
            # install under usr. Those that BusyBox puts in /usr/bin and /usr/sbin then come out
            # under usr/usr, which are the same directories.
            make ${target_triplet:+CROSS_COMPILE=$target_triplet-} \
                CONFIG_PREFIX=$package_install_dir$prefix install
            cp -a $package_install_dir$prefix$prefix/. $package_install_dir$prefix/
            rm -rf $package_install_dir$prefix$prefix
            # The static accounts (root, locked) and the init's table.
            cp -rv $package_files_dir/etc $package_install_dir/
            chmod -v 0600 $package_install_dir/etc/shadow
            ;;
        *)
            default_install
            ;;
    esac
}
