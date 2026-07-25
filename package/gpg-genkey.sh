# Air-gapped GPG keypair generation + USB persistence helper — increment #1
# of the amnesiac, air-gapped GPG appliance objective (see SELF-HOST.md and
# GNUPG-YUBIKEY.md). NOT part of any bootable-* umbrella: installed on
# demand, like ncdu, via `./lfs install gpg-genkey`. Requires the "usb"
# capability's kernel fragment (package/linux/usb.config) to actually have
# a stick to mount at runtime, but that's a runtime concern, not a build
# dependency — this package builds fine regardless of CAPS.
: ${package_version:=0.1.0}

depends() {
    # The keygen-sufficient slice of the gnupg family (see gnupg.sh's own
    # header comment for the full family + its established install order)
    # — everything --quick-generate-key/--export/--export-secret-keys need,
    # deliberately WITHOUT gmp/nettle/libtasn1/gnutls: those exist solely
    # to give dirmngr (keyserver access) a TLS backend, irrelevant to local
    # RAM-only keygen. Without them dirmngr's own configure simply omits
    # dirmngr (not a fatal error — gpg/gpg-agent/scdaemon/pinentry-tty all
    # still build and run fine; see gnupg.sh) — exactly the appliance this
    # increment wants, nothing more.
    #
    # None of these package scripts take any knobs (confirmed by reading
    # each one) — every one derives its own target build from the ambient
    # install scenario install()/target_build_env already set up
    # (package_merge_dir=$INSTALL_DIR/$SYSTEM_KEY, host=$target, ...), so a
    # bare `./lfs install gpg-genkey` brings in the whole appliance
    # userland with one command. Order matters only where a later member's
    # own configure probes an earlier one at configure time (zlib ahead of
    # gnupg, which auto-detects it via pkg-config) — this is the same
    # order GNUPG-YUBIKEY.md's own family table lists.
    require libgpg-error
    require npth
    require libassuan
    require libksba
    require libgcrypt
    require libusb
    require zlib
    require gnupg
    require pinentry
}

install() {
    cd $package_install_dir

    # This package's own stage dir starts empty (the stage->archive->merge
    # inversion, PACKAGING.md — see 9p-config.sh's own comment on the same
    # gotcha), so the destination directory must be created before writing
    # into it.
    mkdir -pv usr/bin

    # A content-only package (no compile step) — model this on 9p-config.sh/
    # network-config.sh's own heredoc-into-the-stage-dir style, just writing
    # a script instead of a config file. Single-quoted 'EOF' so none of the
    # script's own $-expansions are touched by *this* shell.
    cat > usr/bin/gpg-genkey <<'GPGGENKEYEOF'
#!/bin/sh
# gpg-genkey — generate a GPG keypair with secret material living ONLY in
# RAM, then export it (passphrase-protected) to a mounted USB stick.
#
# THE WHOLE POINT (see SELF-HOST.md / GNUPG-YUBIKEY.md): GNUPGHOME is a
# fresh directory under /run — tmpfs under systemd, so it never touches the
# boot disk — and every bit of secret key material gpg writes (the secret
# keyring, the random pool, the auto-generated revocation cert) lives
# there and NOWHERE else. The only place the secret key survives past this
# process's exit is the removable USB stick, passphrase-encrypted. The
# boot medium itself stays discardable: on real hardware (pi0, a later
# increment) that's a read-only/wipeable SD card holding no secrets at
# all. GNUPGHOME is wiped unconditionally on exit — success, failure, or
# interrupt all reach the same cleanup trap below.
#
# Usage: gpg-genkey -n NAME -e EMAIL [-a ALGO] -p PASSPHRASE [-d USB_DEV]
#   -n NAME        Real name for the key's user ID           ($NAME)
#   -e EMAIL       Email for the key's user ID                ($EMAIL)
#   -a ALGO        Key algorithm (default: ed25519)            ($ALGO)
#   -p PASSPHRASE  Passphrase protecting the exported secret key
#                                                          ($PASSPHRASE)
#   -d USB_DEV     Block device to mount as the USB stick
#                                        ($USB_DEV, default /dev/sda)
#
# Every option can also be set as an environment variable of the same name
# (shown above) instead of a flag — handy for scripted use, where passing
# a passphrase as a bare argument would otherwise leak through `ps`.
# Command-line flags win if both are given.
#
# On success, three files land at the root of the USB stick's filesystem:
#   <EMAIL>-secret.asc   armored, passphrase-protected secret key
#   <EMAIL>-public.asc   armored public key
#   <EMAIL>-revoke.asc   armored revocation certificate
set -eu

ALGO=${ALGO:-ed25519}
USB_DEV=${USB_DEV:-/dev/sda}
USB_MOUNT=/mnt/usb

usage() {
    echo "Usage: $(basename "$0") -n NAME -e EMAIL [-a ALGO] -p PASSPHRASE [-d USB_DEV]" >&2
    exit 1
}

while getopts ":n:e:a:p:d:h" opt; do
    case "$opt" in
        n) NAME=$OPTARG ;;
        e) EMAIL=$OPTARG ;;
        a) ALGO=$OPTARG ;;
        p) PASSPHRASE=$OPTARG ;;
        d) USB_DEV=$OPTARG ;;
        h) usage ;;
        :) echo "gpg-genkey: option -$OPTARG requires an argument" >&2; usage ;;
        \?) echo "gpg-genkey: unknown option -$OPTARG" >&2; usage ;;
    esac
done

: ${NAME:?"gpg-genkey: -n NAME (or \$NAME) is required"}
: ${EMAIL:?"gpg-genkey: -e EMAIL (or \$EMAIL) is required"}
: ${PASSPHRASE:?"gpg-genkey: -p PASSPHRASE (or \$PASSPHRASE) is required"}

# --- RAM-only secret material -------------------------------------------
# This mktemp call is the crux of the whole appliance: /run is tmpfs under
# systemd, so GNUPGHOME (and everything gpg ever writes under it) lives in
# RAM only, never on the boot disk. See the header comment above.
GNUPGHOME=$(mktemp -d /run/gnupg.XXXXXX)
chmod 700 "$GNUPGHOME"
export GNUPGHOME
echo "gpg-genkey: GNUPGHOME=$GNUPGHOME (tmpfs, RAM-only)"

MOUNTED=no
cleanup() {
    rc=$?
    if [ "$MOUNTED" = yes ]; then
        umount "$USB_MOUNT" 2>/dev/null || true
    fi
    rm -rf "$GNUPGHOME"
    exit $rc
}
trap cleanup EXIT INT TERM HUP

# --- Mount the USB stick -------------------------------------------------
mkdir -p "$USB_MOUNT"
# Whole-device vfat first (this project's own USB test image has no
# partition table); fall back to the first partition for a real,
# partitioned stick.
if mount -t vfat "$USB_DEV" "$USB_MOUNT" 2>/dev/null; then
    :
elif mount -t vfat "${USB_DEV}1" "$USB_MOUNT" 2>/dev/null; then
    :
else
    echo "gpg-genkey: failed to mount $USB_DEV (or ${USB_DEV}1) as vfat on $USB_MOUNT" >&2
    exit 1
fi
MOUNTED=yes
echo "gpg-genkey: mounted $USB_DEV on $USB_MOUNT"

# --- Generate the keypair, in RAM ----------------------------------------
# NOTE: this GnuPG build rejects the literal "default" expiration keyword
# for --quick-generate-key ("gpg: error: bad value" — confirmed against the
# target gnupg-2.5.17 build); 0 (never expire) is the portable equivalent.
gpg --batch --pinentry-mode loopback --passphrase "$PASSPHRASE" \
    --quick-generate-key "$NAME <$EMAIL>" "$ALGO" cert,sign 0
echo "gpg-genkey: keypair generated in RAM for $EMAIL"

# --- Export secret key, public key, and revocation cert to the stick ----
gpg --batch --pinentry-mode loopback --passphrase "$PASSPHRASE" \
    --armor --export-secret-keys "$EMAIL" > "$USB_MOUNT/$EMAIL-secret.asc"

gpg --armor --export "$EMAIL" > "$USB_MOUNT/$EMAIL-public.asc"

# --quick-generate-key already creates a revocation certificate as a
# matter of course (standard GnuPG practice since 2.1), under
# $GNUPGHOME/openpgp-revocs.d/<FPR>.rev — reuse it rather than separately
# driving --gen-revoke's interactive Q&A dialog, which needs a real
# /dev/tty even under --command-fd plus --pinentry-mode loopback in this
# GnuPG build (confirmed empirically: "gpg: cannot open '/dev/tty'", and
# plain --batch refuses outright with "can't do this in batch mode").
# Exactly one file: this GNUPGHOME never held more than the one key just
# generated above.
revoke_src=""
for f in "$GNUPGHOME"/openpgp-revocs.d/*.rev; do
    [ -f "$f" ] && revoke_src=$f
    break
done
[ -n "$revoke_src" ] || { echo "gpg-genkey: no revocation certificate found under $GNUPGHOME/openpgp-revocs.d" >&2; exit 1; }
cp "$revoke_src" "$USB_MOUNT/$EMAIL-revoke.asc"

sync
echo "gpg-genkey: exported secret/public/revocation for $EMAIL to $USB_MOUNT"

umount "$USB_MOUNT"
MOUNTED=no
echo "gpg-genkey: unmounted $USB_MOUNT"

echo "gpg-genkey: done"
GPGGENKEYEOF

    chmod -v 0755 usr/bin/gpg-genkey
}
