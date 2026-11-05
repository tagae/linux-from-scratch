: ${package_version:=2.3.1}
: ${package_source:=https://files.pythonhosted.org/packages/source/p/pyscard/pyscard-$package_version.tar.gz}
: ${package_source_hash:=sha256:a24356f57a0a950740b6e54f51f819edd5296ee8892a6625b0da04724e9e6c13}
: ${package_description:=Python interface to smart cards, through PC/SC.}
: ${package_license:=LGPL-2.1-or-later}

# The extension module has nothing linked in: it loads libpcsclite.so.1 when a program first asks
# for a smart card, so it builds against the headers only.
build() {
    # SWIG, which generates the module's C code, looks for its library where it was installed to,
    # which is not where the build machine has it.
    export SWIG_LIB=$TOOL_DIR$(swig -swiglib)
    python_wheel
}

install() {
    python_install_wheel

    # The graphical interface needs wxPython.
    rm -rv $package_install_dir$prefix/lib/python${python_version%.*}/site-packages/smartcard/wx
}
