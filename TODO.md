* Patches downloaded from LFS roll with the LFS version, and previous patch versions are removed,
  breaking the builds of packages that use those patches.
* `yubikey-manager` and `fido2` each build their own OpenSSL, which builds it twice in systems that
  have both. Features can require features: a feature for libcrypto that both require would build it
  once.
