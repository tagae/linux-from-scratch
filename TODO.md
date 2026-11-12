* Patches downloaded from LFS roll with the LFS version, and previous patch versions are removed,
  breaking the builds of packages that use those patches.
* CI builds the tools in the jobs of every platform, though they are the same for all of them. The
  `tools-bootstrap` and `tools` phases could run once, in jobs that the platforms' jobs `need`,
  saving the archives under `archive/tools` (and `download/`) in a cache that the platforms restore,
  which saves one build of the tools per platform. A build on the runner and one through Docker
  Compose cannot share it, as their archives record different paths, and the runner's architecture
  is part of the cache's key. `.github/ci/invalidate` already files the tools apart.
* The profiles repeat the block that installs systemd and what it links (`profile/virt.sh` and
  `profile/pi0-pgp.sh`, with options of their own for util-linux). A third profile is the time to
  share it, as a file that profiles source or as a package the profile names.
