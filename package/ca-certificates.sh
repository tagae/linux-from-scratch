# The CA trust store: a single-file PEM bundle of trusted root CA certificates, generated from
# Mozilla's authoritative certdata.txt via make-ca + p11-kit's `trust` tool.

: ${package_version:=NSS_3_126_RTM}
: ${package_source:=https://raw.githubusercontent.com/nss-dev/nss/$package_version/lib/ckfw/builtins/certdata.txt}
: ${package_source_hash:=sha256:81b7f2576333a2e360e673f912d7b0b7a765d836c731003e348a46cac5d37198}
: ${package_description:=CA trust store built from Mozilla root certificates.}
: ${package_license:=MPL-2.0}

package_certdata_file=$DOWNLOAD_DIR/certdata-$package_version.txt

fetch() {
    if ! [ -f $package_certdata_file ]; then
        fetch_url $package_source $DOWNLOAD_DIR
        mv $DOWNLOAD_DIR/certdata.txt $package_certdata_file
    fi
    verify_hash $package_certdata_file $package_source_hash
}

install() {
    # make-ca has p11-kit's `trust extract` turn the anchors it writes into bundles, which requires a
    # trust-policy module registered for those anchors. When run unprivileged, `trust` reads module
    # configs from $XDG_CONFIG_HOME/pkcs11/modules.
    local config_dir=$package_build_dir/config
    mkdir -pv $config_dir/pkcs11/modules
    cat > $config_dir/pkcs11/modules/p11-kit-trust.module <<EOF
module: $TOOL_DIR/usr/lib/pkcs11/p11-kit-trust.so
trust-policy: yes
x-init-reserved: paths=$package_install_dir/etc/pki/anchors
EOF

    # -s/-u: our own openssl and trust, rather than make-ca's /usr/bin defaults.
    XDG_CONFIG_HOME=$config_dir make-ca \
        -C $package_certdata_file \
        -D $package_install_dir \
        -s $TOOL_DIR/usr/bin/openssl \
        -u $TOOL_DIR/usr/bin/trust

    # make-ca leaves its openssl directory read-only.
    chmod -v 755 $package_install_dir/etc/ssl/certs
    cp -fv $package_install_dir/etc/pki/tls/certs/ca-bundle.crt \
           $package_install_dir/etc/ssl/certs/ca-certificates.crt

    # openssl's own compiled-in default CAfile (--openssldir=/etc/ssl).
    ln -sfv certs/ca-certificates.crt $package_install_dir/etc/ssl/cert.pem

    # make-ca reports, but doesn't fail on, unsuccessful extractions.
    grep -q 'BEGIN CERTIFICATE' $package_install_dir/etc/ssl/certs/ca-certificates.crt \
        || bail "No certificates in the generated CA bundle"
}
