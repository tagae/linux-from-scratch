* Patches downloaded from LFS roll with the LFS version, and previous patch versions are removed,
  breaking the builds of packages that use those patches.
* CI builds the tools in the jobs of every platform, though they are the same for all of them. The
  `tools-bootstrap` and `tools` phases could run once, in jobs that the platforms' jobs `need`,
  saving the archives under `archive/tools` (and `download/`) in a cache that the platforms restore,
  which saves one build of the tools per platform. A build on the runner and one through Docker
  Compose cannot share it, as their archives record different paths, and the runner's architecture
  is part of the cache's key. `.github/ci/invalidate` already files the tools apart.
* `yubikey-manager` and `fido2` each build their own OpenSSL, which builds it twice in systems that
  have both. Features can require features: a feature for libcrypto that both require would build it
  once.
* A feature that requires systemd (`fido2`, `yubikey-manager`) brings it to a system with another
  init, which then has two. An init system other than systemd needs a way to refuse that, or
  features that rely on what both inits provide.
* The `util-linux` feature builds util-linux a second time, over the minimal one that systemd brings:
  a package is built once per call, with the options of its call site. Building it once would take
  features adding options to a package before it is built (the option table of
  docs/dependencies-design.md).
