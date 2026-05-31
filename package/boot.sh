: ${package_version:=0.0.1}

install() {
    case $package_component in
        cmdline)
            echo > $package_install_dir/boot/cmdline.txt \
                 console=serial0,115200 \
                 root=LABEL=base rootfstype=btrfs rootflags=subvol=root/$ROOT_VOLUME \
                 rootwait
            ;;
        *)
            default_install
            ;;
    esac
}
