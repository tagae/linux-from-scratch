#!/bin/sh
# Orchestrates the end-to-end self-host proof (docs/design/e2e-cross.md):
# the virt builder guest cross-compiles a pi0 GnuPG image with its own
# arm cross-toolchain, and the host boots it and generates a keypair with
# separate encryption and authentication subkeys. Invoked by `make e2e-test`.
#
# Runtime is measured in hours by design (a full guest cross-toolchain + pi0
# system build); against a warm builder guest each already-built package
# fast-paths, so this doubles as a quick E2-E4 orchestration check.
set -eu
cd "$(dirname "$0")/../.."   # project root

BUILDER_KEY=systemd-busybox-virt+9p+loop
BUILDER_IMG=image/$BUILDER_KEY.img

reap() { pkill -TERM -f 'qemu-system' 2>/dev/null || true; }

# ---- E1: the builder guest image ----------------------------------------
# Absent (pristine state): assemble it container-side — Debian bootstrap ->
# tools -> builder system + baked tool payload -> image, plus the pi0
# baseline that populates the download/ mirror the no-network guest builds
# from. Present (warm): skip straight to E2 (the in-guest steps fast-path).
if [ ! -f "$BUILDER_IMG" ]; then
    echo "e2e-test: E1 - no builder image; assembling from pristine"
    echo "          (Debian bootstrap -> tools -> builder system -> image)..."
    sh tests/e2e/e1-builder-image.sh
fi

# ---- E2 + E3: guest cross-builds the pi0 GnuPG image ---------------------
echo "e2e-test: E2+E3 - booting the builder guest to cross-build the pi0 image"
echo "          (hours from cold; minutes against a warm guest)..."
reap
expect -f tests/e2e/builder.exp

[ -f image/e2e-pi0.img ] || {
    echo "e2e-test: FAIL - the guest did not produce image/e2e-pi0.img"
    exit 1
}
[ -f work/boot/systemd-busybox-pi0/kernel.img ] || {
    echo "e2e-test: FAIL - the guest-built pi0 kernel was not copied out"
    exit 1
}

# ---- E4: host boots the pi0 image and generates the keypair --------------
echo "e2e-test: E4 - booting the guest-built pi0 image (TCG), generating a"
echo "          keypair with separate encryption + authentication subkeys..."
reap
expect -f tests/e2e/keygen.exp
reap

echo "e2e-test: PASS - guest cross-built the pi0 GnuPG appliance; host booted"
echo "          it and generated a keypair with distinct encr + auth subkeys."
