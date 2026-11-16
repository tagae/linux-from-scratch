: ${package_version:=0.1.0}
: ${package_description:=Makes OpenPGP keys for security keys in memory, and exports them to a USB stick.}
: ${package_license:=MIT}

# The stick is mounted by an automount unit, which systemd starts when a program, of any user,
# touches /mnt/usb. Distributions enable units with a preset; nothing here applies presets, so make
# the link that `systemctl enable` makes from the [Install] section.
install() {
    cd $package_install_dir
    cp -rv $package_files_dir/usr .
    mkdir -pv etc/systemd/system/local-fs.target.wants
    ln -sv $prefix/lib/systemd/system/mnt-usb.automount etc/systemd/system/local-fs.target.wants/
}
