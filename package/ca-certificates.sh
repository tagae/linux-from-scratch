# The CA trust store: a single-file PEM bundle of trusted root CA certificates, generated from
# Mozilla's authoritative certdata.txt via make-ca + p11-kit's `trust` tool.

: ${package_version:=NSS_3_126_RTM}
: ${package_source:=https://raw.githubusercontent.com/nss-dev/nss/$package_version/lib/ckfw/builtins/certdata.txt}
: ${package_source_hash:=sha256:81b7f2576333a2e360e673f912d7b0b7a765d836c731003e348a46cac5d37198}

fetch() {
    readonly package_certdata_file=$DOWNLOAD_DIR/certdata-$package_version.txt
    if ! [ -f "$package_certdata_file" ]; then
        fetch_url "$package_source" "$DOWNLOAD_DIR"
        mv $DOWNLOAD_DIR/certdata.txt $package_certdata_file
    fi
    verify_hash "$package_certdata_file" "$package_source_hash"
}

install() {
    local anchordir=$package_install_dir/etc/pki/anchors

    # Guest phase: make-ca/p11-kit/trust are tools that don't exist on the guest.
    if ! command -v make-ca >/dev/null 2>&1; then
        local tarball=$PROJECT_DIR/archive/$SYSTEM_KEY/$package_archive
        [ -f "$tarball" ] || bail "make-ca not on PATH and no tarball at $tarball"
        mkdir -p $package_install_dir
        tar xf "$cross_tarball" -C $package_install_dir
        return 0
    fi

    # make-ca's EXTRACT phase runs p11-kit's `trust extract`, which turns the
    # anchor files make-ca just wrote into the actual bundle — but only if a
    # PKCS#11 trust-policy MODULE is registered pointing at those anchors.
    # p11-kit discovers modules from compiled-in absolute config directories
    # (/usr/share/p11-kit/modules, /etc/pkcs11/modules) that resolve to
    # nothing useful here: TOOL_DIR is never bind-mounted onto the container's
    # real /usr/share or /etc (see docker-compose.yaml — only tools/usr/{bin,
    # lib}), and in the bootstrap container those are Debian's. So p11-kit's
    # OWN installed module config is never found, and `trust extract` reports
    # "no modules containing trust policy are registered" → an empty bundle
    # (the cold-build failure this exact code path exhibited).
    #
    # p11-kit's env overrides (P11_PACKAGE_CONFIG_MODULES/..., via
    # -Denv_override_paths) are NOT honored by `trust` on a clean tree
    # (verified empirically — the module config is simply never discovered
    # through them). What IS honored is p11-kit's user config directory,
    # relocatable via XDG_CONFIG_HOME: `trust` reads
    # $XDG_CONFIG_HOME/pkcs11/modules/*.module. So point it at a throwaway
    # per-invocation config tree holding a trust-module config for THIS run:
    #   module:  absolute path to p11-kit-trust.so (a relative name would be
    #            resolved against p11_module_path and not found).
    #   trust-policy: yes — required; trust/enumerate.c's ca-anchors filter
    #            only considers modules marked as a trust-policy source.
    #   x-init-reserved: paths=$anchordir — module.c's parse_argument() hook
    #            telling the trust module where THIS invocation's anchors are
    #            ($anchordir is DESTDIR-relative, so it differs between the
    #            $TOOL_DIR build and a target-tree build).
    # (Relies on `trust` running as a normal, non-root user — the case for
    # every build_tools()/umbrella invocation — since p11-kit skips user
    # config for root/AT_SECURE processes.)
    local trust_so=$(find $TOOL_DIR/usr -name 'p11-kit-trust.so' | head -1)
    [ -n "$trust_so" ] || bail "p11-kit-trust.so not found under $TOOL_DIR/usr"

    local xdg=$package_build_dir/p11-kit-config
    local moddir=$xdg/pkcs11/modules
    mkdir -p $moddir
    cat > $moddir/p11-kit-trust.module <<EOF
module: $trust_so
priority: 1
trust-policy: yes
x-trust-lookup: pkcs11:library-description=PKCS%2311%20Kit%20Trust%20Module
disable-in: p11-kit-proxy
x-init-reserved: paths=$anchordir
EOF

    # -C: use our pinned certdata.txt rather than make-ca's own -g/--get.
    # -D: DESTDIR — everything make-ca writes (the anchors above, and the
    #     trust/openssl outputs below) is prefixed with this.
    # -s/-u: point make-ca at $TOOL_DIR's own openssl/trust rather than
    #     probing /usr/bin (never populated in this scratch container).
    # -f: force generation — moot in practice (see make-ca's own REVISION
    #     handling: our pinned NSS certdata.txt carries no "# Revision:"
    #     line, so make-ca always regenerates unconditionally regardless),
    #     kept for clarity/future-proofing.
    # XDG_CONFIG_HOME propagates from make-ca to the `trust` subprocess it
    # spawns for the extract step (make-ca doesn't scrub the environment).
    XDG_CONFIG_HOME=$xdg \
        make-ca \
            -C $package_certdata_file \
            -D $package_install_dir \
            -s $TOOL_DIR/usr/bin/openssl \
            -u $TOOL_DIR/usr/bin/trust \
            -f

    # A single concatenated PEM bundle of trusted CA anchors.
    mkdir -p $package_install_dir/etc/ssl/certs
    chmod -v 755 $package_install_dir/etc/ssl/certs
    cp -fv $package_install_dir/etc/pki/tls/certs/ca-bundle.crt \
           $package_install_dir/etc/ssl/certs/ca-certificates.crt

    # openssl's own compiled-in default CAfile (--openssldir=/etc/ssl).
    ln -sfv certs/ca-certificates.crt $package_install_dir/etc/ssl/cert.pem

    grep -q 'BEGIN CERTIFICATE' $package_install_dir/etc/ssl/certs/ca-certificates.crt \
        || bail "$package_install_dir/etc/ssl/certs/ca-certificates.crt has no certificates"
}
