# The GNU tools: the core utilities, grep, sed and gawk.

(
    # One program for all the utilities, which otherwise carry a copy of the same library each.
    single_binary=symlinks
    install_program=hostname
    lfs_system_install coreutils
)
lfs_system_install grep
lfs_system_install sed
lfs_system_install gawk
