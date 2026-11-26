: ${package_version:=4.5}
# Debian's orig tarball, which holds every 4.x version: upstream releases each as a zip archive.
: ${package_source:=https://deb.debian.org/debian/pool/main/d/docbook-xml/docbook-xml_$package_version.orig.tar.gz}
: ${package_source_hash:=sha256:b0f8edcf697f5318e63dd98c9a931f3fee167af0805ba441db372e0f17b2a44f}
: ${package_description:=DocBook XML document type definitions.}
: ${package_license:=DocBook-DTD AND ISO-permission}

# The name of the tarball's directory ends in a revision of Debian's.
package_source_dir=$source_dir/docbook-xml-$package_version.c31424

# Where the catalog of docbook-xsl looks for the definitions.
install() {
    local dest=$package_install_dir$prefix/share/xml/docbook/xml
    mkdir -pv $dest
    cp -r $package_source_dir/docbook-4.* $dest/
}
