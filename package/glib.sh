: ${package_version:=2.90.1}
: ${package_source:=https://download.gnome.org/sources/glib/${package_version%.*}/glib-$package_version.tar.xz}
: ${package_source_hash:=sha256:93c941aa17d5eb1d53fe838365f29a8b4e539c222a256d974ec8f30fc413e396}
: ${package_description:=Core libraries of GNOME: data structures, objects, and I/O.}
: ${package_license:=LGPL-2.1-or-later AND (LGPL-2.1-or-later OR AFL-2.0)}
: ${package_cpe:=a:gnome:glib:$package_version}

prepare() {
    case $package_component in
        glib)
            # A build directory that meson configured earlier keeps its options and compilers:
            # setup leaves it alone, and ninja regenerates it with the old ones.
            find . -mindepth 1 -delete
            ${host:+meson_cross_file}

            # pkgconf puts the sysroot in front of every absolute path in a .pc file, unless told
            # to follow freedesktop's rules, where only flags get it. Meson reads some of them as
            # install directories.
            # Without introspection, documentation, tests, translations, tracing and the optional
            # libraries (SELinux, extended attributes, ELF files for debugging). The mount table
            # comes from util-linux's libmount, as systemd's does.
            env PKG_CONFIG_FDO_SYSROOT_RULES=1 meson setup $package_source_dir \
                ${host:+--cross-file cross.ini} \
                ${prefix:+--prefix=$prefix} \
                --libdir=lib \
                --buildtype=release \
                -Dintrospection=disabled \
                -Ddocumentation=false \
                -Dman-pages=disabled \
                -Dgtk_doc=false \
                -Dtests=false \
                -Dinstalled_tests=false \
                -Dnls=disabled \
                -Ddtrace=disabled \
                -Dsystemtap=disabled \
                -Dsysprof=disabled \
                -Dselinux=disabled \
                -Dxattr=false \
                -Dlibelf=disabled \
                -Dlibmount=enabled \
                -Dglib_debug=disabled
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        glib)
            ninja
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        glib)
            DESTDIR=$package_install_dir ninja install
            cd $package_install_dir

            # The tools that GLib's users run to build (glib-mkenums, glib-compile-resources,
            # gdbus-codegen...) and their data run on the build machine: the system has the
            # libraries only, and not the one for introspection, which nothing here uses.
            ${host:+rm -rfv usr/bin usr/libexec usr/share/gettext usr/share/bash-completion \
                usr/share/gdb usr/share/glib-2.0 usr/lib/libgirepository-2.0.so* \
                usr/include/glib-2.0/girepository usr/lib/pkgconfig/girepository-2.0.pc}

            # The directory of GIO's modules, which nothing here ships.
            find . -type d -empty -delete

            move_to_dev_component usr/lib/glib-2.0 usr/share/aclocal
            move_to_docs_component
            ;;
        dev)
            install_component
            ;;
        *)
            default_install
            ;;
    esac
}
