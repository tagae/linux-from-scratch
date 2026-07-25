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
: ${package_source_hash:=sha256:81b7f2576333a2e360e673f912d7b0b7a765d836c731003e348a46cac5d37198}

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
    verify_hash "$package_certdata_file" "$package_source_hash"
}

install() {
    local anchordir=$package_install_dir/etc/pki/anchors

    # Guest phase: make-ca/p11-kit/trust are container-native build-host
    # tools (installed only into $TOOL_DIR by build_tools(), see there)
    # that simply don't exist on the guest — no amount of path-guarding
    # fixes that, unlike the TOOL_DIR knobs elsewhere on this umbrella path
    # (bootable-systemd.sh, systemd.sh). Special-cased honestly instead:
    # install by extracting the already cross-built tarball for this exact
    # $SYSTEM_KEY (produced by an earlier container-side build of this same
    # package, shared over the 9p mount at $PROJECT_DIR/archive — NOT
    # $ARCHIVE_DIR, which in guest phase is the guest's own local dir, see
    # lfs) — same generation-N trust-store-input lineage as the guest's own
    # native toolchain: each generation is cross-built host==target in the
    # container, then delivered to the guest as an archive tarball —
    # "generation N builds generation N+1", the same lineage as Debian
    # seeding the original cross toolchain. The extracted files land in
    # $package_install_dir exactly like a normal
    # install() would, so the ordinary archive->merge steps below (in
    # lib/package.sh's _install) proceed unchanged from here — the guest
    # re-archives this content into its OWN local ARCHIVE_DIR, same as
    # every other package it builds.
    if ! command -v make-ca >/dev/null 2>&1; then
        local cross_tarball=$PROJECT_DIR/archive/$SYSTEM_KEY/$package_archive
        [ -f "$cross_tarball" ] \
            || bail "make-ca not on PATH (guest) and no cross-built tarball at $cross_tarball"
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
    # -f: both ca-bundle.crt and the ca-certificates.crt it becomes are left
    # read-only (0444) by make-ca/trust, so regenerating into an existing tree
    # (a re-run into $TOOL_DIR, or a rebuilt target tree) must be able to
    # replace an unwritable copy — cp -f removes it and retries.
    mkdir -p $package_install_dir/etc/ssl/certs
    chmod -v 755 $package_install_dir/etc/ssl/certs
    cp -fv $package_install_dir/etc/pki/tls/certs/ca-bundle.crt \
           $package_install_dir/etc/ssl/certs/ca-certificates.crt

    # openssl's own compiled-in default CAfile (--openssldir=/etc/ssl).
    ln -sfv certs/ca-certificates.crt $package_install_dir/etc/ssl/cert.pem

    grep -q 'BEGIN CERTIFICATE' $package_install_dir/etc/ssl/certs/ca-certificates.crt \
        || bail "$package_install_dir/etc/ssl/certs/ca-certificates.crt has no certificates"
}
