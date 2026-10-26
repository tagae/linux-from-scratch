* Patches downloaded from LFS roll with the LFS version, and previous patch versions are removed,
  breaking the builds of packages that use those patches.
* Capabilities are installed in alphabetical order, which is also the order of the system key, so a
  capability works only if its name sorts after the ones it needs (`yubikey` < `yubikey-manager`).
  Nothing declares the dependency: each capability checks for the others it needs in its own file, and
  the check runs only when the install reaches it, after the order is fixed. A capability whose name
  sorts too early fails, or installs without what it needs.
