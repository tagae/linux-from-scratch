#!/bin/sh
# tests/probes.sh -- Stage 2: functional in-guest probes. Boots a real
# image under QEMU (via tests/probe-driver.exp) and asserts on LIVE guest
# behavior -- a DHCP lease actually arriving, a keypair actually round-
# tripping through gpg, a boot medium actually staying byte-identical --
# rather than the static archive/install trees Stage 1 (tests/run.sh)
# checks. Separate from `make check` on purpose: this needs QEMU and
# already-built images (`./lfs system build` + `./lfs image build`), and
# a single probe can take minutes, where Stage 1 is seconds.
#
#   make check-probes             # every tests/probes/*.probe
#   make check-probe PROBE=name   # just tests/probes/name.probe
#   sh tests/probes.sh            # same as check-probes, run directly
#   PROBE=name sh tests/probes.sh # same as check-probe
#
# A probe whose image (image/<PROBE_KEY>.img) doesn't exist yet SKIPs
# (TAP "# SKIP", not a failure) -- see tests/README.md's Stage 1 tiers for
# why that convention matters here too: an incrementally-built tree (not
# every SYSTEM_KEY, not every capability combination) should never turn
# this suite red for something that simply hasn't been built.
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
cd "$PROJECT_DIR"
. "$PROJECT_DIR/tests/tap.sh"

: "${IMAGE_DIR:=$PROJECT_DIR/image}"
PROBES_DIR=$PROJECT_DIR/tests/probes
DRIVER=$PROJECT_DIR/tests/probe-driver.exp

# `make check-probe PROBE=<name>` (or `PROBE=<name> sh tests/probes.sh`)
# runs just that one probe; unset/empty means "every *.probe".
ONLY=${PROBE:-}

# ---- shared helpers available to every probe's probe_host_pre/post() ----

# sha256 FILE -- portable across this project's dev hosts: prefers
# sha256sum (Linux, Homebrew coreutils) and falls back to macOS's
# built-in shasum -a 256. Used by amnesia.probe's byte-identity proof.
sha256() {
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$1" | awk '{print $1}'
    else
        shasum -a 256 "$1" | awk '{print $1}'
    fi
}

# run_in_scratch SCRIPT -- run a shell fragment inside the privileged
# scratch container, with this project's own cross-built losetup/kpartx/
# mkfs.fat/mount etc on PATH (TOOL_DIR, bind-mounted at /mnt/lfs/tools --
# see docker-compose.yaml). This is the OFFLINE forensics route: mount a
# disk image and inspect/verify it without ever booting it, which is what
# amnesia's SHA-256 bracket and usb-persist's stick check both want (the
# alternative -- probing over the live QEMU console -- can't prove
# anything about bytes actually on disk). /mnt/lfs/image is the same
# bind mount `./lfs image build` itself writes into, so paths under
# $IMAGE_DIR (host) and /mnt/lfs/image (container) name the same files.
run_in_scratch() {
    docker compose run --rm --user 0:0 scratch sh -c "$1"
}

# create_usb_stick DEST -- a fresh, empty 64 MiB vfat image at DEST (must
# be under $IMAGE_DIR so the container above can reach it). Whole-device
# vfat, no partition table -- matches gpg-genkey.sh's own "mount -t vfat
# $USB_DEV" (no partition suffix) expectation, and this project's other
# hand-made stick images (image/usb-test.img etc). Re-formatted fresh
# every call, so two probes never share state through a stale stick.
create_usb_stick() {
    dest=$1
    rel=$(basename "$dest")
    run_in_scratch "
        set -e
        PATH=/mnt/lfs/tools/usr/bin:/mnt/lfs/tools/usr/sbin:/mnt/lfs/tools/bin
        fallocate -l 64M /mnt/lfs/image/$rel
        mkfs.fat -F 32 -n PROBE /mnt/lfs/image/$rel
    " >/dev/null 2>&1
}

# ---- PROBE_KEY -> PLATFORM/INIT/CAPS, mirroring `lfs`'s own SYSTEM_KEY
# grammar (bare PLATFORM for systemd, INIT-PLATFORM otherwise, then
# +cap1+cap2... sorted -- see `lfs`'s "Init flavor"/"Capabilities"
# sections and docs/design/capabilities.md). Since every probe's
# PROBE_KEY below is literally the image's own filename stem, this is
# the same string `lfs` folded CAPS into when the image was built, so
# splitting it back apart reconstructs the exact env `./lfs qemu` needs.

derive_platform_init_caps() {
    key=$1
    platform_part=${key%%+*}
    case $key in
        *+*) caps_part=${key#*+} ;;
        *)   caps_part= ;;
    esac
    case $platform_part in
        busybox-*)
            DERIVED_INIT=busybox
            DERIVED_PLATFORM=${platform_part#busybox-}
            ;;
        *)
            DERIVED_INIT=systemd
            DERIVED_PLATFORM=$platform_part
            ;;
    esac
    DERIVED_CAPS=$(printf '%s' "$caps_part" | tr '+' ' ')
}

# ---- run one probe file, reporting exactly one TAP result (ok/not_ok/skip) ----

run_one() {
    probe_file=$1
    name=$(basename "$probe_file" .probe)

    # Fresh state for every probe: a .probe file that forgets to define
    # something (e.g. skips probe_host_post) must never silently inherit
    # the PREVIOUS probe's function/var of the same name.
    unset -f probe_guest probe_host_pre probe_host_post 2>/dev/null || true
    PROBE_KEY=
    PROBE_TIMEOUT=180
    PROBE_ENV=
    # shellcheck disable=SC1090
    . "$probe_file"

    if [ -z "$PROBE_KEY" ]; then
        not_ok "probe:$name declares PROBE_KEY"
        return 0
    fi

    image=$IMAGE_DIR/$PROBE_KEY.img
    if [ ! -f "$image" ]; then
        skip "probe:$name" "image/$PROBE_KEY.img not built"
        return 0
    fi
    if ! command -v probe_guest >/dev/null 2>&1; then
        not_ok "probe:$name defines probe_guest()"
        return 0
    fi

    derive_platform_init_caps "$PROBE_KEY"
    PLATFORM=$DERIVED_PLATFORM
    INIT=$DERIVED_INIT
    CAPS=$DERIVED_CAPS

    PROBE_IMAGE=$image
    PROBE_STICK=
    # The "usb" capability needs a real stick attached for QEMU to expose
    # (see `lfs`'s qemu case: USB_DISK gates the usb-storage device
    # entirely) -- provisioned generically here from CAPS so individual
    # probe files never have to know how to make one. A probe can still
    # override/extend via PROBE_ENV below (e.g. a future probe needing
    # some other env var QEMU or the guest cares about).
    case " $CAPS " in
        *" usb "*)
            PROBE_STICK=$IMAGE_DIR/.probe-usb-$name.img
            if ! create_usb_stick "$PROBE_STICK"; then
                not_ok "probe:$name: create fresh USB stick"
                return 0
            fi
            ;;
    esac

    export PLATFORM INIT CAPS PROBE_TIMEOUT PROBE_IMAGE PROBE_STICK
    if [ -n "$PROBE_STICK" ]; then
        USB_DISK=$PROBE_STICK
        export USB_DISK
    fi
    if [ -n "$PROBE_ENV" ]; then
        eval "export $PROBE_ENV"
    fi

    if command -v probe_host_pre >/dev/null 2>&1; then
        if ! probe_host_pre; then
            not_ok "probe:$name: probe_host_pre"
            return 0
        fi
    fi

    marker=PROBE_OK_$name
    chain_file=$(mktemp "${TMPDIR:-/tmp}/lfs-probe-$name.XXXXXX")
    chain=$(probe_guest)
    printf '%s; sync; poweroff' "$chain" > "$chain_file"

    log=$(mktemp "${TMPDIR:-/tmp}/lfs-probe-$name-log.XXXXXX")
    echo "# probe:$name booting PLATFORM=$PLATFORM INIT=$INIT CAPS='$CAPS' image=$(basename "$image") timeout=${PROBE_TIMEOUT}s"
    set +e
    "$DRIVER" "$image" "$marker" "$chain_file" > "$log" 2>&1
    rc=$?
    set -e
    sed 's/^/# /' "$log"

    if [ "$rc" -ne 0 ]; then
        not_ok "probe:$name (driver exit $rc)"
        return 0
    fi

    if command -v probe_host_post >/dev/null 2>&1; then
        if probe_host_post; then
            ok "probe:$name"
        else
            not_ok "probe:$name: probe_host_post"
        fi
    else
        ok "probe:$name"
    fi
}

# ---- iterate ----

found=0
for probe_file in "$PROBES_DIR"/*.probe; do
    [ -e "$probe_file" ] || continue
    n=$(basename "$probe_file" .probe)
    [ -z "$ONLY" ] || [ "$n" = "$ONLY" ] || continue
    found=$((found + 1))
    run_one "$probe_file"
done

if [ "$found" -eq 0 ]; then
    if [ -n "$ONLY" ]; then
        not_ok "probe:$ONLY exists (no tests/probes/$ONLY.probe)"
    else
        skip "probes" "no tests/probes/*.probe found"
    fi
fi

tap_summary
