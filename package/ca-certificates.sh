# The CA trust store: a single-file PEM bundle of trusted root CA
# certificates, generated from Mozilla's authoritative certdata.txt via
# make-ca + p11-kit's `trust` tool (both native build-host tooling — see
# package/make-ca.sh and package/p11-kit.sh) rather than a pre-converted
# bundle, per this project's from-scratch philosophy.
#
# Installed as a build-host tool into $TOOL_DIR by build_tools() (lib/
# tools.sh) — where it produces the exact file `lfs` points SSL_CERT_FILE
# at, switching scratch-phase downloads (fetch_url in lib/base.sh) from
# unverified fallback to real TLS verification — and again into each
# target system tree via the bootable-{systemd,busybox}.sh umbrellas
# (package_install_dir=$INSTALL_DIR/$SYSTEM_KEY there). Safe in both: the
# generated PEM data is architecture-independent, and the package has no
# runtime dependency on the tree it lands in.
#
# certdata.txt itself is not a tarball, so this overrides fetch() below
# instead of using default_fetch()/get() (see there). package_version is
# an NSS release tag (not a certdata.txt version number of its own) —
# pin one that resolves via raw.githubusercontent.com so the source is
# reproducible and hash-checkable, unlike make-ca's own -g/--get, which
# follows a moving "tip" URL.
: ${package_version:=NSS_3_126_RTM}
: ${package_source:=https://raw.githubusercontent.com/nss-dev/nss/$package_version/lib/ckfw/builtins/certdata.txt}
: ${package_source_sha256:=81b7f2576333a2e360e673f912d7b0b7a765d836c731003e348a46cac5d37198}

# fetch_url names the download after the URL's own basename — a bare
# "certdata.txt" here, regardless of $package_version (see get() in lib/
# base.sh) — so version-qualify the cached copy ourselves; otherwise
# bumping package_version to a newer NSS tag would silently keep re-using
# whatever certdata.txt happened to be cached under that shared name.
package_certdata_file=$DOWNLOAD_DIR/certdata-$package_version.txt

# default_fetch() only knows how to fetch-and-extract https://*.tar.*|*.tgz
# sources (see _source in lib/package.sh); get() itself would try to `tar
# xf` this bare .txt file unconditionally and fail. There is nothing to
# extract or build here anyway — only make-ca to run, in install() below.
fetch() {
    mkdir -p $DOWNLOAD_DIR
    [ -f $package_certdata_file ] || fetch_url "$package_source" "$DOWNLOAD_DIR"
    [ -f $package_certdata_file ] || mv $DOWNLOAD_DIR/certdata.txt $package_certdata_file
    printf '%s  %s\n' "$package_source_sha256" "$package_certdata_file" | sha256sum -c - \
        || bail "Integrity check failed for certdata.txt (expected sha256 $package_source_sha256)"
}

install() {
    local anchordir=$package_install_dir/etc/pki/anchors

    # p11-kit's `trust` tool (make-ca's own backend for turning the anchor
    # files it writes below into actual trust-store output formats) finds
    # its PKCS#11 modules and their config via compiled-in absolute paths
    # (sysconfdir=/etc, pkgdatadir=/usr/share/..., libdir=/usr/lib/...) —
    # real filesystem paths that resolve correctly for p11-kit's own,
    # single, always-in-$TOOL_DIR install (package/p11-kit.sh), but this
    # scratch container's actual root never bind-mounts TOOL_DIR onto it
    # (see Dockerfile.scratch / docker-compose.yaml: only tools/usr/{bin,
    # lib} are, never tools/etc or tools/usr/share) — so those compiled-in
    # paths would resolve against an empty/nonexistent real /etc or
    # /usr/share, finding no module at all, regardless of which tree this
    # invocation is actually generating certs into ($TOOL_DIR itself, or a
    # target's $INSTALL_DIR/$SYSTEM_KEY via the bootable-* umbrellas).
    #
    # p11-kit.sh builds with -Denv_override_paths=enabled specifically for
    # this: it honors P11_PACKAGE_CONFIG_MODULES/P11_SYSTEM_CONFIG_MODULES/
    # P11_USER_CONFIG_MODULES at runtime (see p11-kit/modules.c's
    # p11_get_paths_from_env), letting us point `trust` at a throwaway
    # module-config directory generated fresh per invocation below, whose
    # "x-init-reserved: paths=" line (module.c's own hook for exactly this
    # — see parse_argument()) tells the trust module where THIS
    # invocation's anchors actually landed: $anchordir, which is
    # DESTDIR-relative and so differs between the $TOOL_DIR build and a
    # target-tree build. The module .so itself is referenced by absolute
    # path (found below), so no separate P11_MODULE_PATH override is
    # needed — module.c's own loader only consults p11_module_path for
    # relative module filenames.
    local trust_so=$(find $TOOL_DIR/usr -name 'p11-kit-trust.so' | head -1)
    [ -n "$trust_so" ] || bail "p11-kit-trust.so not found under $TOOL_DIR/usr"

    local moddir=$package_build_dir/pkcs11-modules
    mkdir -p $moddir
    # Mirrors p11-kit's own installed trust/p11-kit-trust.module, with an
    # absolute "module:" path (see above) and a non-empty "x-init-reserved"
    # pointing at this invocation's own anchor directory. trust-policy: yes
    # is required — trust/enumerate.c's ca-anchors filter only considers
    # modules explicitly marked as a trust-policy source.
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
    P11_PACKAGE_CONFIG_MODULES=$moddir \
    P11_SYSTEM_CONFIG_MODULES=$moddir \
    P11_USER_CONFIG_MODULES=$moddir \
        make-ca \
            -C $package_certdata_file \
            -D $package_install_dir \
            -s $TOOL_DIR/usr/bin/openssl \
            -u $TOOL_DIR/usr/bin/trust \
            -f

    # The contract file every scratch-phase download's fetch_url (lib/
    # base.sh) checks for via SSL_CERT_FILE (`lfs`): a single concatenated
    # PEM bundle of trusted CA anchors. make-ca's own `trust extract
    # --format=pem-bundle --purpose server-auth` step above already wrote
    # the equivalent bundle at .../pki/tls/certs/ca-bundle.crt (BLFS/
    # make-ca's own conventional location) — place it at the path this
    # project's own openssl (built with --openssldir=/etc/ssl) and `lfs`
    # both expect instead.
    #
    # chmod: `trust extract --format=openssl-directory` (above, via
    # make-ca) leaves etc/ssl/certs itself mode 0555 (its own read-only-
    # trust-store convention) — put back the standard, writable 0755 so we
    # (and anything else touching this tree later) can still add to it.
    mkdir -p $package_install_dir/etc/ssl/certs
    chmod -v 755 $package_install_dir/etc/ssl/certs
    cp -v $package_install_dir/etc/pki/tls/certs/ca-bundle.crt \
          $package_install_dir/etc/ssl/certs/ca-certificates.crt

    # openssl's own compiled-in default CAfile (--openssldir=/etc/ssl).
    ln -sfv certs/ca-certificates.crt $package_install_dir/etc/ssl/cert.pem

    grep -q 'BEGIN CERTIFICATE' $package_install_dir/etc/ssl/certs/ca-certificates.crt \
        || bail "$package_install_dir/etc/ssl/certs/ca-certificates.crt has no certificates"
}
