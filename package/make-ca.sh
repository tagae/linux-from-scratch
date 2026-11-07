# Turns Mozilla's certdata.txt into a PKCS#11 anchor directory and, via p11-kit's `trust extract`,
# the actual trust-store outputs (openssl directory, PEM bundles, Java cacerts).

: ${package_version:=1.16.1}
: ${package_source:=https://github.com/lfs-book/make-ca/archive/v$package_version/make-ca-$package_version.tar.gz}
: ${package_source_hash:=sha256:98c7e6fded1938b972d0177b5d5e925d318be87f84ee9e4cad680656a8c29414}
: ${package_description:=CA trust store generation script.}
: ${package_license:=MIT OR GPL-3.0-only}

prepare() {
    apply_patch $package_files_dir/mktemp-without-t.patch
}

install() {
    make -C $package_source_dir \
        install_bin install_conf install_cs install_mozilla_ca_root \
        DESTDIR=$package_install_dir
}
