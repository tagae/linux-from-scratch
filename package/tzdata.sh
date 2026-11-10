: ${package_version:=2026e}
: ${package_source:=https://data.iana.org/time-zones/releases/tzdata$package_version.tar.gz}
: ${package_source_hash:=sha256:b26882805f26aac59d5b222978e6580484b834ccdc98be89df2f05a6dc53a652}
: ${tzcode_source:=https://data.iana.org/time-zones/releases/tzcode$package_version.tar.gz}
: ${tzcode_source_hash:=sha256:cc3d27ca2a0d8399504551b920970d80af83bfb9c216e8082a15491921935d54}
: ${package_description:=Time zone database.}
: ${package_license:=LicenseRef-Public-Domain}
: ${package_cpe:=none}

# The data and the code that compiles it come in two tarballs, which unpack into the same
# directory, without one of their own. The code is built for the build machine, as it compiles the
# data here; only the compiled zones are installed.
fetch() {
    [ -d $package_source_dir ] || {
        rm -rf $package_source_dir.tmp
        mkdir -p $package_source_dir.tmp
        fetch_tarball $package_source $package_source_hash
        fetch_tarball $tzcode_source $tzcode_source_hash
        mv $package_source_dir.tmp $package_source_dir
    }
}

fetch_tarball() {
    local file=$DOWNLOAD_DIR/${1##*/}
    [ -f $file ] || fetch_url $1 $DOWNLOAD_DIR
    verify_hash $file $2
    tar xf $file -C $package_source_dir.tmp
}

build() {
    make -C $package_source_dir CC=gcc
}

install() {
    make -C $package_source_dir install CC=gcc DESTDIR=$package_install_dir
    # The programs it installs run on the build machine, and /etc/localtime is for the image to
    # choose.
    rm -rf $package_install_dir/etc $package_install_dir/usr/bin $package_install_dir/usr/sbin \
        $package_install_dir/usr/lib
    move_to_docs_component
}
