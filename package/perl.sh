: ${package_version:=5.42.2}
: ${package_source:=https://www.cpan.org/src/5.0/perl-$package_version.tar.xz}
: ${package_source_hash:=sha256:0a585eeb9e363c0f80482ddb3571625250c2c86aeb408853e8ea50805cfb14bb}

# Custom build system (Configure, not autoconf) — native only by default,
# no --host/--build. A target-scenario build (SELF-HOST.md M3) instead
# opts into Configure's OWN -Dusecrosscompile mechanism: it derives
# ar/nm/ranlib from $cc by substituting "-gcc" (matching this project's own
# $target-prefixed binutils names — see binutils.sh's install()) and, since
# no -Dtargethost is given (nothing to SSH compiled test programs to at
# build time), Configure builds a throwaway native "host miniperl" of its
# own in a nested source/host/ subdir first and uses THAT to answer the
# handful of probes that would otherwise need to execute target code.
# Confirmed empirically to produce a genuine AArch64, dynamically-linked
# perl — no separate perl-cross-style patch set needed. host= guards it so
# every existing native caller (build_tools()'s own `install perl`) is
# unaffected.
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
