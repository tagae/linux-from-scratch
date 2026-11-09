* Patches downloaded from LFS roll with the LFS version, and previous patch versions are removed,
  breaking the builds of packages that use those patches.
* `yubikey-manager` and `fido2` each build their own OpenSSL, which builds it twice in systems that
  have both. Features can require features: a feature for libcrypto that both require would build it
  once.
* A feature that requires systemd (`fido2`, `yubikey-manager`) brings it to a system with another
  init, which then has two. An init system other than systemd needs a way to refuse that, or
  features that rely on what both inits provide.
