: ${package_version:=4.5.1}
: ${package_source:=https://downloads.sourceforge.net/project/swig/swig/swig-$package_version/swig-$package_version.tar.gz}
: ${package_source_hash:=sha256:7fec50b27deddab5455a9633780b6341eddfb96215a7619e93a76eb27178f653}
: ${package_description:=Generator of interfaces between C code and scripting languages.}
: ${package_license:=GPL-3.0-or-later}

prepare() {
    # PCRE serves regular expressions in renames, which the interfaces built here do not use. The
    # compiler cache that comes with it is of no use here.
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --without-pcre \
        --disable-ccache
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
