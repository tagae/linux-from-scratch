: ${package_version:=1.79.2}
: ${package_source:=https://github.com/docbook/xslt10-stylesheets/releases/download/release/$package_version/docbook-xsl-nons-$package_version.tar.bz2}
: ${package_source_hash:=sha256:ee8b9eca0b7a8f89075832a2da7534bce8c5478fc8fc2676f512d5d87d832102}
: ${package_description:=DocBook XSL stylesheets, which make manual pages from DocBook sources.}
: ${package_license:=DocBook-XML AND Zlib}

package_source_dir=$source_dir/docbook-xsl-nons-$package_version

# The stylesheets of manual pages and of HTML, with what they import, and the XML catalog, through
# which these and docbook-xml's definitions are found.
install() {
    local dest=$package_install_dir$prefix/share/xml/docbook/xsl
    mkdir -pv $dest
    cd $package_source_dir
    cp -r VERSION.xsl common highlighting html lib manpages profiling $dest/
    cp -rv $package_files_dir/etc $package_install_dir/
}
