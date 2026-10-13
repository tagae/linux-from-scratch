# Security keys on USB, such as the YubiKey. The kernel support (package/linux/yubikey.config) makes
# the key's FIDO2 interface appear as /dev/hidraw*, which libfido2's tools (fido2-token, fido2-cred
# and fido2-assert) drive. The key's OpenPGP card is reached by GnuPG's scdaemon over the same USB
# support, so using it takes the gnupg capability as well.

(
    # Only libcrypto is wanted: not the openssl program, its documentation or the legacy provider,
    # nor the directories for certificates and configuration.
    disable="apps docs legacy" ssldirs=no
    lfs_system_install openssl
    lfs_install_package openssl#dev
)
lfs_system_install libcbor
lfs_install_package libcbor#dev
lfs_system_install libfido2
