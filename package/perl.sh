: ${package_version:=5.42.2}
: ${package_source:=https://www.cpan.org/src/5.0/perl-$package_version.tar.xz}
: ${package_source_hash:=sha256:0a585eeb9e363c0f80482ddb3571625250c2c86aeb408853e8ea50805cfb14bb}
: ${package_description:=Perl programming language.}
: ${package_license:=Artistic-1.0-Perl OR GPL-1.0-or-later}

prepare() {
    : ${shrplib:=yes}
    : ${relocatable:=no}

    local privlib_version=${package_version%.*}
    # Configure relocates only the library paths it derives itself; ones given to it must start
    # with .../, which stands for the directory of the perl binary.
    local lib_prefix=$([ $relocatable = yes ] && echo .../.. || echo ${prefix:-/usr})
    cd $package_source_dir
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
    make -C $package_source_dir
}

install() {
    make -C $package_source_dir install DESTDIR=$package_install_dir
}
