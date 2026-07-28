# tests/probes/amnesia.sh -- the strongest proof the "amnesia"
# capability has: not just that / *feels* read-only from inside the
# guest, but that the boot medium's bytes are IDENTICAL before and after
# a full boot -> use -> poweroff cycle (see docs/design/amnesia.md's
# "The proof" section). Two layers:
#   1. in-guest: `touch /x` on the ro root fails with a read-only-fs
#      error -- the cheap, fast half of the claim.
#   2. host-side, offline: the image FILE's own SHA-256 is unchanged
#      across the whole boot. This is the half that actually matters --
#      an overlay-based "read-only" design could pass check 1 while still
#      writing to the underlying device; this design (real `ro` mount +
#      targeted tmpfs, no overlay) is supposed to never touch the medium
#      at all, and this is what would catch a regression that broke that
#      (e.g. btrfs log-tree replay writing on mount without
#      rescue=nologreplay -- see amnesia.md).
PROBE_KEY=systemd-busybox-virt+amnesia+usb
PROBE_TIMEOUT=180

probe_guest() {
    printf '%s' 'touch /x 2>&1 | grep -qi read-only && echo PROBE_OK_amnesia'
}

# $PROBE_IMAGE is exported by tests/probes.sh before either hook runs.
probe_host_pre() {
    _AMNESIA_SHA_BEFORE=$(sha256 "$PROBE_IMAGE")
    echo "# amnesia: $PROBE_IMAGE sha256 before boot: $_AMNESIA_SHA_BEFORE"
}

probe_host_post() {
    sha_after=$(sha256 "$PROBE_IMAGE")
    echo "# amnesia: $PROBE_IMAGE sha256 after boot:  $sha_after"
    [ "$sha_after" = "$_AMNESIA_SHA_BEFORE" ]
}
