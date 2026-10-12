: ${package_version:=0.1.0}
: ${package_description:=Raspberry Pi firmware configuration and kernel command line.}
: ${package_license:=MIT}

install() {
    mkdir -pv $package_install_dir/boot
    cd $package_install_dir/boot

    # The platform's device tree, which the firmware would otherwise pick by board revision, under
    # its downstream name. The serial console is the system's only console.
    cat > config.txt <<EOF
device_tree=${dev_tree_blob##*/}
enable_uart=1
EOF

    # The root file system is the subvolume that images boot (see lib/image.sh).
    echo "$kernel_cmdline rootfstype=btrfs rootflags=subvol=root/$ROOT_VOLUME rw rootwait" \
         > cmdline.txt
}
