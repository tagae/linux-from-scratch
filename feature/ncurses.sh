# ncurses, the terminal library that util-linux's more and cfdisk, procps' top and texinfo's info
# link.

(
    shared=yes normal=no debug=no ada=no cxx_binding=no stripping=no
    # The descriptions of the terminals these systems meet are built into the library, instead of a
    # database of every known terminal.
    fallbacks=dumb,linux,vt100,vt220,xterm,xterm-256color db_install=no
    pc_files=yes pkg_config_libdir=/usr/lib/pkgconfig
    lfs_system_install ncurses
    lfs_install_package ncurses#dev
)
