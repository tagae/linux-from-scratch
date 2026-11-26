: ${package_version:=2.15.4}
: ${package_source:=https://download.gnome.org/sources/libxml2/${package_version%.*}/libxml2-$package_version.tar.xz}
: ${package_source_hash:=sha256:98087fd181d9070724f3fbc65c7377db03038eb92bd882374daff44940138821}
: ${package_description:=XML parser and toolkit.}
: ${package_license:=MIT AND ISC}

# Under `sysconfdir` is the XML catalog, which names the local copies of what documents refer to on
# the web.
prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${sysconfdir:+--sysconfdir=$sysconfdir} \
        --disable-static \
        --without-python
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
    # The libtool archive makes libtool look for the library where it is not.
    rm -v $package_install_dir$prefix/lib/libxml2.la
    move_to_docs_component
}
