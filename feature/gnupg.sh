# GnuPG, to make and use OpenPGP keys offline: there is no network, no key server, and no X.509.
# Smart cards, such as the OpenPGP card of a YubiKey, are reached through scdaemon's own CCID
# driver over libusb. gpg-genkey makes a key in memory and exports it to a USB stick.

# Requires: usb usb-storage

( languages=no; lfs_system_install libgpg-error )
lfs_install_package libgpg-error#dev

# The packages below look for libgpg-error with gpgrt-config, a script that runs on the build
# machine and tells where the sysroot keeps it, instead of with the one they would find there.
export GPGRT_CONFIG=$sysroot/usr/bin/gpgrt-config

lfs_system_install libassuan
lfs_install_package libassuan#dev
lfs_system_install libgcrypt
lfs_install_package libgcrypt#dev
lfs_system_install libksba
lfs_install_package libksba#dev
lfs_system_install npth
lfs_install_package npth#dev

# Without udev, libusb finds the devices through sysfs.
( udev=no; lfs_system_install libusb )
lfs_install_package libusb#dev

(
    # Only gpg, gpg-agent and scdaemon, with nothing that reaches the network or handles X.509
    # certificates. The CCID driver is required, so that a missing libusb is an error.
    sysconfdir=/etc
    gpgsm=no dirmngr=no keyboxd=no tpm2d=no wks_tools=no gpgtar=no
    tofu=no photo_viewers=no
    ccid_driver=yes
    lfs_system_install gnupg
)

(
    # Asks for passphrases and PINs on the terminal.
    pinentry_tty=yes
    pinentry_curses=no fallback_curses=no
    lfs_system_install pinentry
)

lfs_system_install gpg-genkey
