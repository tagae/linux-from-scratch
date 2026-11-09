* Patches downloaded from LFS roll with the LFS version, and previous patch versions are removed,
  breaking the builds of packages that use those patches.
* `yubikey-manager` and `fido2` each build their own OpenSSL, which builds it twice in systems that
  have both. Features can require features: a feature for libcrypto that both require would build it
  once.
* A feature that requires systemd (`fido2`, `yubikey-manager`) brings it to a system with another
  init, which then has two. An init system other than systemd needs a way to refuse that, or
  features that rely on what both inits provide.
* The minimum that systemd brings keeps ncurses, for util-linux's `more`, which man and systemd's
  tools page through, and `cfdisk`: a package is built once per system, so util-linux cannot gain
  them in a later feature. A stricter minimum would build util-linux without them (`cfdisk` needs
  an option of its own), and give the `man` feature a pager.
