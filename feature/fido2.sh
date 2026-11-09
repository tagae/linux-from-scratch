# FIDO2 security keys, such as the YubiKey, through libfido2's tools (fido2-token, fido2-cred and
# fido2-assert), which drive the key's FIDO2 interface through /dev/hidraw*.

# Linux: hidraw usb

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
