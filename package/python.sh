: ${package_version:=3.14.10}
: ${package_source:=https://www.python.org/ftp/python/$package_version/Python-$package_version.tar.xz}
: ${package_source_hash:=sha256:de414a57119abef52784d8993e341d53aed635fc2b05c2607d9f98a2c5b72032}
: ${package_description:=Python programming language.}
: ${package_license:=Python-2.0.1}

package_source_dir=$SOURCE_DIR/Python-$package_version

: ${build_python:=$TOOL_DIR/usr/bin/python3}

prepare() {
    case $package_component in
        python)
            : ${shared:=yes}
            : ${optimizations:=no} ${ensurepip:=no} ${test_modules:=no}
            : ${static_libpython:=no}

            # OpenSSL 4 support, from the LFS book's patches, 13.1, which names it for the Python of
            # the book, 3.14.7. It is several patches in a row and applies, with offsets, to the
            # later releases of 3.14.
            apply_patch $package_files_dir/Python-3.14.7-openssl_4-1.patch

            # The remote debugger, which attaches to a running process, is left out.

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
                --without-remote-debug \
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

                # A module is no program, and this one is marked as one: its first line runs
                # `python`, which the system lacks (only python3).
                chmod -v -x $lib/encodings/rot_13.py

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
