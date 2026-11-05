# Python Packages
# ---------------
#
# Helpers for the recipes of Python packages, which install into the site-packages of the platform.
# They are for the Python whose version is `python_version`, which the framework sets.

# Prints where the platform's Python keeps its standard library, in the tree being installed.
python_lib_dir() {
    echo $prefix/lib/python${python_version%.*}
}

# Prints where the platform's Python looks for the packages that are installed.
python_site_packages() {
    echo $(python_lib_dir)/site-packages
}

# Installs modules, directories or files of the package's source, into site-packages.
python_install_modules() {
    local site_packages=$package_install_dir$(python_site_packages)
    mkdir -pv $site_packages
    cp -rv "$@" $site_packages/
    python_compile
}

# Builds the wheel of a Python package from a copy of its source, with the Python of TOOL_DIR. For
# the platform, that Python takes the compiler, the flags and the file names of extension modules
# from the platform's sysconfigdata, and the headers come from the sysroot.
python_wheel() (
    find . -mindepth 1 -delete
    cp -r $package_source_dir/. .
    # Extension modules are compiled and linked with the flags that the Python they are for built
    # its own with (-DNDEBUG included), which its sysconfigdata records.
    unset CFLAGS LDFLAGS
    if [ -n "${host:-}" ]; then
        local lib=$sysroot$(python_lib_dir)
        export _PYTHON_SYSCONFIGDATA_PATH=$lib
        export _PYTHON_SYSCONFIGDATA_NAME=$(basename $lib/_sysconfigdata_*.py .py)
        export CPPFLAGS=-I$sysroot$prefix/include/python${python_version%.*}
    fi
    $TOOL_DIR/usr/bin/python3 -m pip wheel --no-build-isolation --no-deps --no-index \
        --no-cache-dir --disable-pip-version-check --wheel-dir dist .
)

# Unpacks the wheel into site-packages. The tools on the build machine read the package's metadata
# (setuptools finds its commands in it), which nothing on the platform does.
python_install_wheel() {
    local site_packages=$package_install_dir$(python_site_packages)
    mkdir -pv $site_packages
    $TOOL_DIR/usr/bin/python3 -m zipfile -e dist/*.whl $site_packages
    [ -z "${host:-}" ] || rm -rf $site_packages/*.dist-info
    python_compile
}

# Compiles the byte code of what the package installs in the platform's site-packages, which
# nothing at run time has to write, like that of the standard library. The Python of TOOL_DIR
# writes its own.
python_compile() {
    [ -n "${host:-}" ] || return 0
    local site_packages=$(python_site_packages)
    $TOOL_DIR/usr/bin/python3 -m compileall -q -j0 -d $site_packages \
        --invalidation-mode unchecked-hash $package_install_dir$site_packages
}
