Supply-chain trust
==================

Every input is authenticated and pinned; nothing is fetched or built
from bytes the repo doesn't vouch for.

Source pinning
--------------

* Every package declares `package_source_hash=sha256:<hex>` — verified
  (`verify_hash`, lib/base.sh) against the on-disk archive before every
  unpack, cached downloads included. The algorithm prefix (SRI/Nix
  style) dispatches to the matching `<algo>sum`, so individual packages
  can move to stronger digests with no framework change.
* Upstream refs are IMMUTABLE: release tarballs or release tags, never
  branch archives (kernel-config.md). A hash mismatch therefore means
  tampering or corruption, never "upstream moved".
* Hash provenance is anchored in the (YubiKey-signed) git history.
  SHA-256's second-preimage resistance is what the pin relies on;
  upstream PGP signature verification remains the known next rung.

Transport
---------

`fetch_url` ALWAYS verifies TLS against `$SSL_CERT_FILE` and refuses to
download if the bundle is missing — there is no unverified fallback
anywhere. Defence in depth: TLS authenticates the mirror, the sha256
pin authenticates the bytes.

The from-scratch CA store
-------------------------

Per project philosophy, the trust store is generated, not copied: a
pinned, hash-checked Mozilla `certdata.txt` (an NSS release tag) is
converted by make-ca + p11-kit's `trust` (both built as build-host
tools) into the PEM bundle. The bootstrap phase builds the chain
(libffi → libtasn1 → p11-kit → make-ca → ca-certificates) and stages
the bundle to `work/certs/` so the scratch phase verifies against OUR
bundle from its very first download — never a copy of Debian's. The
same package installs the bundle into every target tree
(`/etc/ssl/certs/ca-certificates.crt`), giving built systems working
TLS (proven end-to-end: gpg fetched a key over hkps through this
bundle). On guests, where make-ca doesn't exist, the package installs
from its own cross-built tarball — generation-N lineage, same as the
toolchain.

Notable implementation constraints (details in the package scripts):
p11-kit's trust module needs an XDG_CONFIG_HOME-relocated module config
(its env overrides don't reach `trust extract`), and a non-multiarch
libdir; make-ca outputs are 0444 (regeneration needs `cp -f`).
