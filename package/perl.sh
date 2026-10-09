: ${package_version:=5.42.2}
: ${package_source:=https://www.cpan.org/src/5.0/perl-$package_version.tar.xz}
: ${package_source_hash:=sha256:0a585eeb9e363c0f80482ddb3571625250c2c86aeb408853e8ea50805cfb14bb}
: ${package_description:=Perl programming language.}
: ${package_license:=Artistic-1.0-Perl OR GPL-1.0-or-later}

prepare() {
    local privlib_version=${package_version%.*}
    cd $package_source_dir
    sh Configure -des \
        ${host:+-Dusecrosscompile} \
        -D cc=${host:+$host-}gcc \
        -D prefix=${prefix:-/usr} \
        -D vendorprefix=${prefix:-/usr} \
        -D privlib=${prefix:-/usr}/lib/perl5/$privlib_version/core_perl \
        -D archlib=${prefix:-/usr}/lib/perl5/$privlib_version/core_perl \
        -D sitelib=${prefix:-/usr}/lib/perl5/$privlib_version/site_perl \
        -D sitearch=${prefix:-/usr}/lib/perl5/$privlib_version/site_perl \
        -D vendorlib=${prefix:-/usr}/lib/perl5/$privlib_version/vendor_perl \
        -D vendorarch=${prefix:-/usr}/lib/perl5/$privlib_version/vendor_perl \
        -D useshrplib \
        -D usethreads
}

build() {
    make -C $package_source_dir
}

install() {
    make -C $package_source_dir install DESTDIR=$package_install_dir
}
