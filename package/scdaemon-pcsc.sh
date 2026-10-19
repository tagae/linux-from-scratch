: ${package_version:=0.1.0}
: ${package_description:=Makes scdaemon, of GnuPG, reach smart cards through pcscd.}
: ${package_license:=MIT}

install() {
    mkdir -pv $package_install_dir/etc/gnupg

    # scdaemon drives USB readers with a CCID driver of its own, which claims the reader's USB
    # interface and so leaves none for pcscd's. Without it, scdaemon goes through pcscd, which
    # programs such as ykman use too.
    echo disable-ccid > $package_install_dir/etc/gnupg/scdaemon.conf
}
