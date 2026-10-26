* Patches downloaded from LFS roll with the LFS version, and previous patch versions are removed,
  breaking the builds of packages that use those patches.
* Features are installed in alphabetical order, and can require capabilities only: a feature that
  needs another's packages installs them itself (`yubikey-manager` builds its own OpenSSL, as
  `fido2` does), which builds them twice in systems that have both.
