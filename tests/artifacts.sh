#!/bin/sh
# tests/artifacts.sh -- Tier 2: assertions over whatever archive/<key>/ and
# install/<key>/ trees already exist. Never builds anything; SKIPs (not
# fails) any SYSTEM_KEY that isn't present, so the suite stays useful
# incrementally as more platforms/flavors get built.
#
# Runs inside the scratch container: `install/` is a named Docker volume,
# invisible on the host, and the per-target readelf binaries live in
# `tools/`, also a named volume.
#   docker compose run --rm scratch sh tests/artifacts.sh
set -eu

PROJECT_DIR=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
. "$PROJECT_DIR/tests/tap.sh"

# This script intentionally doesn't go through `lfs` (there's no single
# PLATFORM/USERLAND to select -- it surveys every SYSTEM_KEY that already
# exists), so it re-derives just the directory defaults `lfs` itself would
# apply.
: "${ARCHIVE_DIR:=$PROJECT_DIR/archive}"
: "${INSTALL_DIR:=$PROJECT_DIR/install}"
: "${TOOL_DIR:=$PROJECT_DIR/tools}"

# ---- helpers ----

# Map a SYSTEM_KEY (ALWAYS USERLAND-PLATFORM, optionally +CAP...) back to its
# bare PLATFORM by matching against the known lib/platform/*.sh names --
# see `lfs` for the exact SYSTEM_KEY grammar this mirrors.
platform_for_key() {
    key=$1
    base=${key%%+*}
    for pf in "$PROJECT_DIR"/lib/platform/*.sh; do
        p=$(basename "$pf" .sh)
        case $base in
            *"-$p")
                echo "$p"
                return 0
                ;;
        esac
    done
    return 1
}

# A platform's cross target triple, read straight out of its own
# lib/platform/*.sh rather than sourced -- sourcing more than one in the
# same shell would collide on each file's own `readonly target=...`. vendor
# always defaults to "scratch" in every platform file (never overridden by
# anything that also gets archived), so substitute it textually.
target_for_platform() {
    grep -m1 'readonly target=' "$PROJECT_DIR/lib/platform/$1.sh" \
        | sed -E 's/.*target=//; s/\$\{vendor:-scratch\}/scratch/'
}

# Expected e_machine bytes (ELF header offset 18, 2 bytes little-endian) for
# a target triple's leading arch component.
expected_machine_bytes() {
    case $1 in
        aarch64-*) echo "b7 00" ;;
        arm-*) echo "28 00" ;;
        *) echo "" ;;
    esac
}

elf_machine_bytes() {
    od -An -tx1 -j 18 -N 2 "$1" 2>/dev/null | awk '{print $1, $2}'
}

# ---- archive/<key>/: tarball + ORDER assertions ----

if [ -d "$ARCHIVE_DIR" ]; then
    archive_keys_found=0
    for dir in "$ARCHIVE_DIR"/*/; do
        [ -d "$dir" ] || continue
        archive_keys_found=$((archive_keys_found + 1))
        key=$(basename "$dir")

        for tb in "$dir"*.tar.xz; do
            [ -e "$tb" ] || continue
            name=$key/$(basename "$tb")

            # Catches the empty-160-byte-tarball class: a stale stamp once
            # shipped an "archived" package with nothing in it. NOTE: some
            # real packages here (9p-config, amnesia-config, network-config,
            # busybox-init, boot's -cmdline/-config components) legitimately
            # archive just one or two tiny files -- their real tarballs run
            # ~270-700 bytes, so a flat "> 1 KB" floor would flag them as
            # false positives. A genuinely EMPTY tar.xz (just the "./" root
            # entry, xz-compressed) is reproducibly ~160 bytes regardless of
            # which package produced it (confirmed empirically against this
            # tree's own stale archive/virt+9p and archive/busybox-pi0
            # tarballs); 200 bytes is comfortably above that floor and
            # comfortably below every legitimate tarball's size, so it still
            # catches the class without flagging real tiny packages.
            size=$(wc -c < "$tb" | tr -d ' ')
            if [ "$size" -gt 200 ]; then
                ok "archive/$name is larger than 200 bytes"
            else
                not_ok "archive/$name is larger than 200 bytes (got $size bytes -- the stale-stamp empty-tarball class)"
            fi

            # The authoritative "not empty" signal, independent of size: a
            # bare tar always lists its own "./" root dir as one entry, so
            # "more than one entry" -- not just "more than zero" -- is what
            # actually proves real content was archived.
            entries=$(tar tf "$tb" 2>/dev/null | wc -l | tr -d ' ')
            if [ "${entries:-0}" -gt 1 ]; then
                ok "archive/$name: tar tf lists more than just the root entry"
            else
                not_ok "archive/$name: tar tf lists more than just the root entry (got $entries)"
            fi

            # FHS-rooted: at least one of the canonical merged-usr top dirs
            # is present, i.e. this really is a prefix=/usr-staged package
            # tree and not, say, a wrong-root/absolute-path extraction.
            # Deliberately NOT "every entry is under one of these roots" --
            # perl's own tarball is known to also carry a large number of
            # stray top-level pod/doc files (see tests/README.md), a
            # separate, pre-existing packaging quirk out of this suite's
            # scope; the point here is catching a wholesale wrong-root
            # archive, not auditing every path.
            roots=$(tar tf "$tb" 2>/dev/null | sed 's#^\./##; s#/$##' | grep -v '^$' | awk -F/ '{print $1}' | sort -u)
            if printf '%s\n' "$roots" | grep -qxE 'usr|etc|bin|boot|sbin|lib|var'; then
                ok "archive/$name is FHS-rooted (usr/etc/bin/boot/... present at top level)"
            else
                not_ok "archive/$name is FHS-rooted (usr/etc/bin/boot/... present at top level)"
            fi
        done

        order_file=${dir}ORDER
        if [ -f "$order_file" ]; then
            ok "archive/$key/ORDER exists"

            missing=0
            while IFS= read -r line; do
                [ -n "$line" ] || continue
                [ -f "$dir$line" ] || missing=$((missing + 1))
            done < "$order_file"
            if [ "$missing" -eq 0 ]; then
                ok "archive/$key/ORDER: every listed tarball is present on disk"
            else
                not_ok "archive/$key/ORDER: every listed tarball is present on disk ($missing missing)"
            fi

            orphans=0
            for tb in "$dir"*.tar.xz; do
                [ -e "$tb" ] || continue
                grep -qxF "$(basename "$tb")" "$order_file" || orphans=$((orphans + 1))
            done
            if [ "$orphans" -eq 0 ]; then
                ok "archive/$key: no tarball is missing from ORDER"
            else
                not_ok "archive/$key: no tarball is missing from ORDER ($orphans orphan(s))"
            fi
        else
            not_ok "archive/$key/ORDER exists"
        fi
    done
    if [ "$archive_keys_found" -eq 0 ]; then
        skip "archive/ tarball checks" "no archive/<key>/ directories built yet"
    fi
else
    skip "archive/ tarball checks" "$ARCHIVE_DIR does not exist"
fi

# ---- install/<key>/: ELF arch canary + gnupg family NEEDED checks ----

if [ -d "$INSTALL_DIR" ]; then
    install_keys_found=0
    for dir in "$INSTALL_DIR"/*/; do
        [ -d "$dir" ] || continue
        install_keys_found=$((install_keys_found + 1))
        key=$(basename "$dir")

        platform=$(platform_for_key "$key") || platform=""
        if [ -z "$platform" ]; then
            skip "install/$key: ELF arch canary" "key does not map to a known lib/platform/*.sh"
        else
            target=$(target_for_platform "$platform")
            expected=$(expected_machine_bytes "$target")
            canary=""
            for c in usr/bin/busybox usr/lib/libc.so.6; do
                if [ -f "$dir$c" ]; then
                    canary=$c
                    break
                fi
            done
            if [ -z "$canary" ]; then
                skip "install/$key: ELF arch canary" "no canary binary present (tried usr/bin/busybox, usr/lib/libc.so.6)"
            else
                got=$(elf_machine_bytes "$dir$canary")
                if [ "$got" = "$expected" ]; then
                    ok "install/$key/$canary has the right ELF arch for $platform ($expected)"
                else
                    not_ok "install/$key/$canary has the right ELF arch for $platform (expected $expected, got '$got')"
                fi
            fi
        fi

        # gnupg family: asserted only when actually present -- it's an
        # opt-in package (`./lfs install gnupg`), never part of the base
        # system, so most keys legitimately don't have it at all.
        readelf=""
        if [ -n "$platform" ]; then
            target=$(target_for_platform "$platform")
            readelf=$TOOL_DIR/bin/$target-readelf
        fi

        gpg=${dir}usr/bin/gpg
        if [ -f "$gpg" ]; then
            if [ -z "$platform" ] || ! [ -x "$readelf" ]; then
                skip "install/$key/usr/bin/gpg links libgcrypt" "no target readelf available for this key"
            elif "$readelf" -d "$gpg" 2>/dev/null | grep NEEDED | grep -q libgcrypt; then
                ok "install/$key/usr/bin/gpg links libgcrypt (NEEDED)"
            else
                not_ok "install/$key/usr/bin/gpg links libgcrypt (NEEDED)"
            fi
        fi

        scdaemon=${dir}usr/libexec/scdaemon
        if [ -f "$scdaemon" ]; then
            if [ -z "$platform" ] || ! [ -x "$readelf" ]; then
                skip "install/$key/usr/libexec/scdaemon links libusb" "no target readelf available for this key"
            elif "$readelf" -d "$scdaemon" 2>/dev/null | grep NEEDED | grep -q libusb; then
                ok "install/$key/usr/libexec/scdaemon links libusb (NEEDED)"
            else
                not_ok "install/$key/usr/libexec/scdaemon links libusb (NEEDED)"
            fi
        fi
    done
    if [ "$install_keys_found" -eq 0 ]; then
        skip "install/ tree checks" "no install/<key>/ directories built yet"
    fi
else
    skip "install/ tree checks" "$INSTALL_DIR does not exist"
fi

tap_summary
