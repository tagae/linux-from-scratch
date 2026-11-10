# The tools to watch processes and memory: ps, top, free, pgrep and the like, from procps-ng. top
# links ncurses.

# Requires: ncurses

# util-linux provides kill.
( kill=no; lfs_system_install procps-ng )
