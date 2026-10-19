: ${package_version:=3.14.7}
: ${package_source:=https://www.python.org/ftp/python/$package_version/Python-$package_version.tar.xz}
: ${package_source_hash:=sha256:3b48dac8fb59f62eaa67ac83c1eb12bda1b7a08406dd286e252c11a66be27f81}
: ${package_description:=Python programming language.}
: ${package_license:=Python-2.0.1}

package_source_dir=$SOURCE_DIR/Python-$package_version

: ${build_python:=$TOOL_DIR/usr/bin/python3}

prepare() {
    case $package_component in
        python)
            : ${shared:=yes}
            : ${optimizations:=$([ -n "${host:-}" ] && echo no || echo yes)}
            : ${static_libpython:=no}

            patch_source https://www.linuxfromscratch.org/patches/lfs/$lfs_version/Python-$package_version-openssl_4-1.patch \
                sha256:707a0c457192ac2f3b5b8a51481bc5ebd12db22d57c1dbe0256138ee6e070792

            # When cross-compiling, configure cannot look at the platform's device files: it has
            # /dev/ptmx, and /dev/ptc belongs to AIX. Nor can it tell whether getaddrinfo works,
            # unless told whether the platform has IPv6 (`ipv6`).
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${host:+--with-build-python=$build_python} \
                ${shared:+--enable-shared=$shared} \
                ${system_expat:+--with-system-expat} \
                ${static_libpython:+--with-static-libpython=$static_libpython} \
                ${optimizations:+--enable-optimizations=$optimizations} \
                ${ipv6:+--enable-ipv6=$ipv6} \
                ${ensurepip:+--with-ensurepip=$ensurepip} \
                ${test_modules:+--enable-test-modules=$test_modules} \
                ${host:+ac_cv_file__dev_ptmx=yes ac_cv_file__dev_ptc=no}
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        python)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        python)
            make install DESTDIR=$package_install_dir
            # A native build, which is a tool for the build machine, keeps everything it installs.
            if [ -n "${host:-}" ]; then
                local version=${package_version%.*}
                local lib=$package_install_dir$prefix/lib/python$version

                # What building extension modules needs, besides the headers and libpython: the
                # script and the descriptions of the build that tell how to compile and link them.
                # _sysconfigdata stays, as the sysconfig module reads it at run time (zoneinfo
                # does).
                move_to_dev_component \
                    usr/bin/python3-config usr/bin/python$version-config \
                    "usr/lib/python$version/config-$version-*" \
                    "usr/lib/python$version/_sysconfig_vars_*" \
                    usr/lib/python$version/build-details.json
                move_to_docs_component

                # Neither pip, nor Tk, nor the documentation that pydoc shows is installed, which
                # leaves the programs and modules that need them without a use. Until a package
                # installs there, site-packages holds only a note; the packages' recipes make it.
                rm -rf $lib/ensurepip $lib/venv $lib/idlelib $lib/tkinter \
                       $lib/turtledemo $lib/turtle.py $lib/pydoc_data $lib/site-packages
                rm -f $package_install_dir$prefix/bin/idle3* $package_install_dir$prefix/bin/pydoc3*

                # Byte code for what is left, which nothing at run time has to write. A hash of
                # the source that is never checked ties each file to its source, whatever times
                # the files get. The paths in the byte code are those of the installed system.
                find $lib -name __pycache__ -prune -exec rm -rf {} +
                $build_python -m compileall -q -j0 -d $prefix/lib/python$version \
                    --invalidation-mode unchecked-hash $lib
            fi
            ;;
        dev)
            install_component
            ;;
        *)
            default_install
            ;;
    esac
}
