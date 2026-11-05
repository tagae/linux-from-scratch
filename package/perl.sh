: ${package_version:=5.44.0}
: ${package_source:=https://www.cpan.org/src/5.0/perl-$package_version.tar.xz}
: ${package_source_hash:=sha256:505cf43912e9480495c344c70260452e32aa2a73c546a026b3f100053b23ce91}
: ${package_description:=Perl programming language.}
: ${package_license:=Artistic-1.0-Perl OR GPL-1.0-or-later}

prepare() {
    : ${shrplib:=yes}
    : ${relocatable:=no}

    local privlib_version=${package_version%.*}
    # Configure relocates only the library paths it derives itself; ones given to it must start
    # with .../, which stands for the directory of the perl binary.
    local lib_prefix=$([ $relocatable = yes ] && echo .../.. || echo ${prefix:-/usr})
    # Perl builds only in the tree that Configure ran in, and a second Configure over a built tree
    # leaves its extensions stale, so build from a fresh copy of the source.
    find . -mindepth 1 -delete
    cp -Rp $package_source_dir/. .
    # Configure ignores LDFLAGS from the environment, and looks for libraries in the build machine's
    # own directories unless given a sysroot.
    # A relocatable @INC is incompatible with a shared libperl, whose rpath is absolute.
    sh Configure -des \
        ${host:+-Dusecrosscompile} \
        -D cc=${CC:-${host:+$host-}gcc} \
        ${sysroot:+-D sysroot=$sysroot} \
        ${LDFLAGS:+-D ldflags="$LDFLAGS"} \
        ${perlpath:+-D perlpath=$perlpath -D startperl="#!$perlpath"} \
        $([ $relocatable = yes ] && echo -D userelocatableinc) \
        -D prefix=${prefix:-/usr} \
        -D vendorprefix=${prefix:-/usr} \
        -D privlib=$lib_prefix/lib/perl5/$privlib_version/core_perl \
        -D archlib=$lib_prefix/lib/perl5/$privlib_version/core_perl \
        -D sitelib=$lib_prefix/lib/perl5/$privlib_version/site_perl \
        -D sitearch=$lib_prefix/lib/perl5/$privlib_version/site_perl \
        -D vendorlib=$lib_prefix/lib/perl5/$privlib_version/vendor_perl \
        -D vendorarch=$lib_prefix/lib/perl5/$privlib_version/vendor_perl \
        $([ $shrplib = yes ] && echo -D useshrplib) \
        -D usethreads
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
