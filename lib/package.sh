install() {
    case "${1:-help}" in
        help)
            echo "Usage: $(basename "$0") install <PACKAGE>..."
            echo ""
            if [ $# -eq 1 ]; then exit 0; else exit 1; fi
            ;;
    esac

    # Guard on package_install_dir, NOT package_merge_dir: lib/tools.sh
    # calls this SAME install() function directly (bare `install <pkg>`
    # inside build_tools()/bootstrap_tools()) with package_install_dir
    # already explicitly pre-set (e.g. =$TOOL_DIR) — that pre-set value is
    # what must suppress target_build_env there, exactly as before this
    # feature existed. target_build_env no longer sets package_install_dir
    # itself (it sets package_merge_dir instead — see there), so guarding
    # on package_merge_dir would fire target_build_env even for those
    # tools-phase calls, wrongly handing them a package_merge_dir and
    # making _install archive/merge $TOOL_DIR itself.
    if [ -n "${package_install_dir:-}" ]; then
        : # lib/tools.sh already pre-set an explicit scenario — leave it alone.
    elif ! _os_is_build_host; then
        target_build_env
    else
        # Self vs foreign, decided the same way target_sysroot_cc's own
        # kernel_headers guard decides it (see there): $TOOL_DIR/$target/
        # usr/include only exists once guest-phase `./lfs tools bootstrap`
        # (E2, docs/design/guest-cross-builder.md) has built a per-$target
        # sysroot here — which only happens for a FOREIGN platform (the
        # guest's own arch is served by the native-toolchain-delivered
        # $target-gcc already on /usr/bin, no TOOL_DIR sysroot needed or
        # ever built). Foreign target -> the target scenario (host=$target,
        # stage+archive+merge into $INSTALL_DIR/$SYSTEM_KEY), exactly like
        # a scratch-phase cross-install -- the gnupg family (and anything
        # else with a target_sysroot_cc opt-in) hard-requires host=$target
        # to configure at all. Self target -> guest_build_env's existing
        # "ad-hoc install merges into the live /" behavior (self-hosting.md),
        # completely unchanged for virt/pi4/pi5's own ad-hoc installs.
        if [ -d "$TOOL_DIR/$target/usr/include" ]; then
            target_build_env
        else
            guest_build_env
        fi
    fi

    # DESTINATION (-d) picks an explicit, caller-chosen install location —
    # this bypasses the stage->archive->merge inversion entirely (it would
    # be actively wrong to archive a DESTDIR install meant for e.g. a
    # device or .img and then merge it into $INSTALL_DIR/$SYSTEM_KEY
    # instead), so unset whatever target_build_env just set above.
    if [ -n "${DESTINATION:-}" ]; then
        unset package_merge_dir
        if [ -d "$DESTINATION" ]; then
            package_install_dir=$(realpath "$DESTINATION")
        elif [ -f "$DESTINATION" ]; then
            IMAGE="$DESTINATION" image
            package_install_dir=$ROOT_DIR
        elif [ -b "$DESTINATION" ]; then
            DEVICE="$DESTINATION" device
            package_install_dir=$ROOT_DIR
        elif [ "${DESTINATION%.img}" != "$DESTINATION" ]; then
            IMAGE="$DESTINATION" image
            package_install_dir=$ROOT_DIR
        else
            mkdir -pv "$DESTINATION"
            package_install_dir=$(realpath "$DESTINATION")
        fi
    fi

    require "$@"
}

# Build and install one or more packages. Public: this is the worker
# behind the `install` command, and an umbrella package's depends() calls
# it to pull in its members (optionally with knob prefixes, e.g.
# `manpages=no require kmod`) — exactly as build_tools()/a system build
# drive installs. Each package builds in its own subshell with freshly
# derived package_* paths (see _source); ambient knobs (host, prefix,
# package_install_dir, package_variant, CC, …) are inherited from the
# caller, so an umbrella sets a member's scenario simply by prefixing.
require() {
    for pkg in "$@"; do
        (
            _source "$pkg"
            stage "$package_product"
            _install
        )
    done
}

# The build environment shared by every package installed into a
# platform's target system tree. Set once per install scenario (by
# install() for a bare invocation; inherited by an umbrella's members),
# so no package carries its own copy. Defaults only ( := ),
# so a caller (or -d DESTINATION handling above) can still override.
#
# Sets package_merge_dir, NOT package_install_dir: every package under this
# scenario DESTDIR-installs into its own framework-default per-package
# staging dir instead (package_install_dir's own default, further down in
# _source) and is archived + merged into package_merge_dir afterwards (see
# _install) — the stage->archive->merge inversion. Tools-phase scenarios
# (lib/tools.sh) set package_install_dir explicitly themselves and never
# call target_build_env, so they never set package_merge_dir and
# _install's archive/merge steps stay a no-op there.
target_build_env() {
    : ${host:=$target}
    : ${prefix:=/usr}
    # SYSTEM_KEY, not bare $PLATFORM: it carries the init flavor too (see
    # lfs), so a busybox tree and a systemd tree for the same platform get
    # separate stamps and install dirs. Equal to $PLATFORM for the default
    # (systemd) flavor, so existing builds are unaffected.
    : ${package_variant:=$SYSTEM_KEY}
    : ${package_merge_dir:=$INSTALL_DIR/$SYSTEM_KEY}
}

# The build environment for a guest-phase install (LFS_PHASE=guest):
# building NATIVELY, inside the booted system itself, with that system's
# own toolchain — install() applies this when nothing
# is preset, mirroring target_build_env above. package_merge_dir=/: merge
# writes straight into the LIVE system rather than a build-host install
# tree (default_merge's guest-phase branch below handles the mechanics).
#
# Critically, host is deliberately left UNSET (target_build_env's first
# line, `: ${host:=$target}`, has no equivalent here): every package's
# configure then runs with host=build, i.e. a genuine native build, not a
# cross one. Two things depend on host staying unset:
#   - target_sysroot_cc's own guard, `[ "${host:-}" = "$target" ]`, fails
#     with host unset, so it returns immediately and never overrides CC —
#     self-neutralizing, no guest-specific change needed there.
#   - package scripts' own `: ${build:=$(gcc -dumpmachine)}` guards
#     (gmp.sh, mpfr.sh, mpc.sh, ...) resolve harmlessly to the guest's own
#     native triple, since that's exactly what bare `gcc -dumpmachine`
#     reports when run on the guest itself.
guest_build_env() {
    : ${prefix:=/usr}
    : ${package_variant:=$SYSTEM_KEY}
    : ${package_merge_dir:=/}
}

# Guest archive-parity check: a freshly-booted guest starts with only
# busybox tar (no xz applet, so it can neither produce nor extract the
# .tar.xz default_archive/default_merge use — see _install's and
# default_merge's own guest-phase branches below) — but once its own tool
# tarballs (tar.sh + xz.sh, the "archive-parity enablers", delivered like
# the rest of the toolchain rather than rebuilt in-guest) are unarchived
# into it, the guest gains a real GNU tar and xz and can run the whole
# stage->archive->merge dance for real, exactly like the container.
# Checked fresh on every call (cheap: two PATH lookups) instead of cached,
# so installing xz/tar mid-session is picked up by the very next package,
# with no separate "capability refresh" step needed.
_guest_has_archive_tools() {
    command -v xz >/dev/null 2>&1 || return 1
    tar --version 2>/dev/null | grep -q GNU
}

# Compile against the packages already installed into the target system
# tree ($INSTALL_DIR/$PLATFORM) rather than the toolchain's own default
# sysroot. A package opts in (from its own script) when it links a library
# an earlier package installed there — util-linux's libtool relink, the
# gnupg family — see project-system-sysroot for the ld-script rationale.
# No-op unless building for the cross target (host=$target), so the same
# call is harmless where build_tools() reuses these scripts natively.
target_sysroot_cc() {
    [ "${host:-}" = "$target" ] || return 0

    # Kernel UAPI headers: normally the container's own per-target
    # sysroot ($TOOL_DIR/$target/usr/include, see tools_bootstrap). A
    # guest-phase build of the guest's OWN arch (LFS_PHASE=guest, target ==
    # the guest's own arch) never runs `./lfs tools bootstrap` at all — no
    # TOOL_DIR sysroot exists there — but its own live /usr/include DOES
    # have them (unarchived straight onto "/" — see native-toolchain.sh);
    # --sysroot below routes ALL *implicit* header search through $sysroot
    # (=$INSTALL_DIR/$SYSTEM_KEY, a fresh per-build staging tree with no
    # kernel headers of its own — the guest's own system build never
    # require()s linux#headers into it), making those live headers
    # invisible unless explicitly re-added — confirmed empirically, not
    # "harmless when missing" as first assumed: util-linux's own
    # configure reported sys/mount.h, sys/ioctl.h, sys/socket.h, etc.
    # all missing despite a real, populated guest /usr/include.
    #
    # A guest CROSS-building a FOREIGN platform (docs/design/guest-cross-
    # builder.md's E2/E3) is different: `LFS_PHASE=guest ./lfs tools
    # bootstrap` DOES build a genuine per-$target sysroot at
    # $TOOL_DIR/$target (TOOL_DIR guest-local, /var/lfs/tools — see lfs's
    # guest-phase dir defaults), seeded by the guest's own native gcc, and
    # that sysroot's headers are the ONLY correct ones for $target (the
    # guest's own live /usr/include is for the guest's own, DIFFERENT,
    # arch). Existence, not phase alone, distinguishes the two guest
    # scenarios — same check install()'s own guest-phase branch uses to
    # pick target_build_env vs guest_build_env. Computed once, ahead of
    # the CC/CXX branches below (both need it).
    local kernel_headers=$TOOL_DIR/$target/usr/include
    if [ ! -d "$kernel_headers" ]; then
        kernel_headers=/usr/include
    fi

    # Stage the cross-compiler's OWN shared libgcc_s.so.1 into the target
    # tree, once, idempotently: nothing else ever installs it there —
    # native-toolchain.sh's own copy is guest-self-hosting-only (host==
    # target, an entirely different, opt-in scenario) — yet it's exactly
    # the file the "-L/usr/lib" libtool quirk above falls through to when
    # the explicit "-L$sysroot/usr/lib" doesn't have it (confirmed the
    # hard way: util-linux's libmount relink on a genuine cross target,
    # "/usr/lib/libgcc_s.so.1: file not recognized" — the SAME wrong-arch-
    # /usr/lib story as that comment's libc case, just for libgcc_s
    # instead, which nothing had staged into $sysroot/usr/lib yet to win
    # the search before the fallback). `-print-file-name` asks the
    # compiler itself, so this is right regardless of the target's own
    # multilib libdir convention (lib vs lib64). Harmless where a same-
    # arch target's own accidental /usr/lib fallback already "worked" —
    # this just also places a correct, target-owned copy where the final
    # image needs one anyway (any dynamically-linked target binary needs
    # its own libgcc_s.so.1 at RUNTIME on the target, not just at link
    # time). cp -n: never clobber a copy a later, more specific package
    # (e.g. native-toolchain.sh, when explicitly installed) may prefer.
    local target_libgcc_s=$($target-gcc -print-file-name=libgcc_s.so.1)
    if [ -f "$target_libgcc_s" ] && [ ! -e "$INSTALL_DIR/$SYSTEM_KEY/usr/lib/libgcc_s.so.1" ]; then
        mkdir -p "$INSTALL_DIR/$SYSTEM_KEY/usr/lib"
        cp -n "$target_libgcc_s" "$INSTALL_DIR/$SYSTEM_KEY/usr/lib/libgcc_s.so.1"
        ln -sf libgcc_s.so.1 "$INSTALL_DIR/$SYSTEM_KEY/usr/lib/libgcc_s.so"
    fi

    if [ -z "${CC:-}" ]; then
        # Explicit -L, not just --sysroot: libtool's own `--mode=install`
        # relink (util-linux's libmount->libblkid, triggered by DESTDIR now
        # differing from --prefix — see package_install_dir's own per-
        # package stage default) rebases ITS dependencies' recorded libdir
        # (e.g. libblkid.la's libdir=/usr/lib) two ways at once: it adds
        # "-L$inst_prefix_dir/usr/lib" (correct — finds this package's own
        # just-staged siblings) AND ALSO keeps the ORIGINAL, un-rebased
        # "-L/usr/lib" verbatim (a libtool quirk, not this project's doing).
        # --sysroot alone does NOT save us here: it only adjusts the
        # compiler's OWN *implicit* default search paths, never an
        # explicit -L such as that leftover one — so plain "/usr/lib"
        # (this container's real root, i.e. the NATIVE toolchain's own
        # runtime — see docker-compose.yaml) gets searched for "-lc" too,
        # and on same-arch targets (e.g. virt on an aarch64 build host)
        # that's architecture-COMPATIBLE, so ld silently links against the
        # wrong (native, not target-merged) glibc instead of erroring; on a
        # different-arch target (pi0/arm on an aarch64 host) it hard-fails
        # ("file format not recognized" — the canary this was caught on).
        # An explicit "-L$sysroot/usr/lib" here, ahead of anything libtool
        # appends later, wins the search unconditionally either way.
        CC="$target-gcc --sysroot=$INSTALL_DIR/$SYSTEM_KEY -idirafter $kernel_headers -L$INSTALL_DIR/$SYSTEM_KEY/usr/lib"
    fi
    # CXX mirrors CC exactly (same guard, same flags, just $target-g++):
    # every existing caller of this function (mpfr.sh, mpc.sh, util-linux.sh,
    # btrfs-progs.sh) builds pure C, so a bare, un-sysroot'd CXX never
    # mattered before — but gcc.sh's own native-for-target build (host=
    # $target, cross-building the native toolchain that ships to guests as
    # archive tarballs — see native-toolchain.sh) is C++ (GCC's own sources,
    # and libstdc++-v3 in the same combined build), and its final cc1 link is
    # run through $(CXX), not $(CC) — confirmed empirically: a bare
    # "$target-g++" (CXX left untouched by this function) hit the exact same
    # "-L/usr/lib" wrong-arch-libc canary this function's own CC branch above
    # already documents, just on the C++ side. Guarded identically, so it's
    # a no-op for every other caller.
    if [ -z "${CXX:-}" ]; then
        CXX="$target-g++ --sysroot=$INSTALL_DIR/$SYSTEM_KEY -idirafter $kernel_headers -L$INSTALL_DIR/$SYSTEM_KEY/usr/lib"
    fi
    export CC CXX
}

version() {
    (
        _source $1
        echo $package_version
    )
}

fetch() {
    (
        _source $1
        fetch
    )
}

archive() {
    (
        _source $1
        stage "$package_product"
        _archive
    )
}

# Extract a package tarball anywhere: FILE [DEST], DEST defaulting to this
# system key's own merged tree. DEST deliberately never defaults to bare
# "/" — inside the build containers /usr/{bin,lib} are read-only bind
# mounts of the toolchain itself (see docker-compose.yaml), so extracting
# there would be wrong at best and fail outright at worst. A live guest
# (which has a real, writable "/" and no such mounts) passes "/" itself,
# explicitly.
unarchive() {
    local file=$1
    local dest=${2:-$INSTALL_DIR/$SYSTEM_KEY}
    echo "Unarchiving $file to $dest..."
    mkdir -p "$dest"
    tar xf "$file" -C "$dest"
}

# This function executes in the subshell that evaluates package scripts.
# Hence, whatever it defines will be available only in the subshell.
# Functions with a leading underscore denote private API that packages shouldn't invoke.
_source() {
    # Clear any package_* left over from an enclosing package: an umbrella
    # calls require() for its members from within its own subshell, so
    # without this the umbrella's own name/version/paths would be inherited
    # and, being already set, shadow each member's own values (the defaults
    # below only assign when unset). package_install_dir, package_variant
    # and package_merge_dir are deliberately NOT cleared — they are the
    # ambient install scenario, meant to carry from an umbrella (or
    # build_tools / tools) down to every member.
    unset package_name package_component package_version package_branch \
          package_source package_source_hash \
          package_release package_files_dir package_source_dir \
          package_work_dir package_build_dir package_product \
          package_deliverable package_archive package_meta

    : ${package_name:=${1%#*}}
    : ${package_component=${1#*#}}

    [ -f $PACKAGE_DIR/$package_name.sh ] || bail "Unknown package '$package_name'"

    _once() {
        local step=$1
        if [ -f $package_build_dir/.$step-$package_component ]; then
            echo "$step (done)"
        else
            # NOT "$step && touch ..." (reverted — found while diagnosing
            # the in-guest system build's 9p mount silently never working):
            # bash's errexit exemption for the left side of "&&" applies to that
            # command's ENTIRE execution, including everything a called
            # shell FUNCTION does internally — so with $step on the left of
            # &&, a failure anywhere inside e.g. install() (a plain shell
            # function, not a subshell) was silently swallowed instead of
            # aborting the build: the function kept running past the failed
            # command, "touch" was correctly skipped (short-circuited, so
            # the stamp wasn't wrongly created), but the overall build just
            # carried on as if nothing had gone wrong (confirmed
            # empirically — package/9p-config.sh's `cat > etc/fstab`
            # failed with ENOENT on a from-scratch stage dir and the
            # system build finished "successfully" regardless, silently
            # producing a tarball with no fstab at all). Splitting into two
            # statements makes $step a bare, untested command again, so
            # errexit fires immediately on failure like everywhere else in
            # this codebase; touch only runs at all if $step succeeded,
            # since a failure aborts (via errexit) before reaching it —
            # same stamp semantics as before, minus the silent swallow.
            $step
            touch $package_build_dir/.$step-$package_component
        fi
    }

    _install() {
        mkdir -p $package_build_dir $package_install_dir
        cd $package_build_dir
        # Dependencies first. For a meta/umbrella package (package_meta=yes)
        # depends() is the whole recipe — it require()s the members and
        # there is no payload of its own. Run every time (unstamped) so a
        # rebuild re-checks the whole set; each member is still fast-pathed
        # by its own install stamp. For an ordinary package depends() is the
        # no-op default below.
        #
        # depends() must NOT hand its own require()d members MY
        # package_install_dir: require()'s subshell forks the whole variable
        # scope, so without this every member would inherit it unchanged
        # instead of deriving its own fresh per-package stage dir (see
        # _source) — exactly the bug this once had, where every member of an
        # umbrella landed inside the UMBRELLA's own stage dir instead of its
        # own. Scoped to the target scenario (package_merge_dir set): under
        # lib/tools.sh, sharing one hand-picked package_install_dir (e.g.
        # =$TOOL_DIR) across many `install <pkg>` calls in a block is exactly
        # the intended behavior, so this save/restore is a no-op there.
        if [ -n "${package_merge_dir:-}" ]; then
            local _own_install_dir=$package_install_dir
            unset package_install_dir
            depends
            package_install_dir=$_own_install_dir
        else
            depends
        fi
        [ "${package_meta:-}" = yes ] && return 0
        ( _once fetch; )
        ( _once prepare; )
        ( _once build; )
        ( _once install; )
        # Stage->archive->merge inversion, scoped to the target scenario:
        # only when target_build_env (or a caller) set
        # package_merge_dir. Tools-phase scenarios (lib/tools.sh) never set
        # it, so `install` above is the final destination there, exactly as
        # before this feature existed — no archive, no merge, no new stamps.
        if [ -n "${package_merge_dir:-}" ]; then
            mkdir -p $package_merge_dir
            # Guest-phase archive parity (conditional now that tar+xz
            # arrive as delivered tool tarballs; earlier, guest phase
            # skipped archiving unconditionally): a tool-less guest still
            # can't produce the .tar.xz default_archive writes (no xz
            # applet in busybox tar), so this stays skipped there —
            # default_merge's own guest-phase fallback copies the stage dir
            # straight into the live system with a plain tar pipe instead.
            # But once the guest has unarchived its own delivered tar+xz
            # tarballs (_guest_has_archive_tools), it archives for real,
            # into its own guest-local ARCHIVE_DIR (see `lfs`'s guest-phase
            # DOWNLOAD_DIR/SOURCE_DIR/WORK_DIR/ARCHIVE_DIR overrides —
            # already guest-local by construction, no change needed here),
            # and default_merge extracts that tarball exactly as the
            # container does — the same continuous self-test extracting
            # the tarball rather than cp-ing the stage dir gives everywhere
            # else. The merge stamp itself is unaffected either way — same
            # semantics, same _once gating, in every phase.
            if _guest_has_archive_tools; then
                ( _once archive; )
            fi
            ( _once merge; )
        fi
    }

    _archive() {
        stage "Archiving $package_product"
        _install
        archive
    }

    fetch() {
        default_fetch
    }

    prepare() {
        default_prepare
    }

    build() {
        default_build
    }

    install() {
        default_install
    }

    archive() {
        default_archive
    }

    merge() {
        default_merge
    }

    # Overridden by umbrella packages (see package_meta) to require() their
    # members; a no-op for ordinary packages.
    depends() {
        :
    }

    default_fetch() {
        case ${package_source:-none} in
            https://*.tar.*|https://*.tgz)
                get $package_source ${package_source_hash:-}
                ;;
            https://github.com*|https://git.*)
                git_checkout $package_source $package_branch $package_source_dir
                ;;
            none)
                echo "$package_product: nothing to fetch"
                ;;
            *)
                bail "Unsupported package source: $package_source"
                ;;
        esac
    }

    default_prepare() {
        echo "$package_product: nothing to prepare"
    }

    default_build() {
        echo "$package_product: nothing to build"
    }

    default_install() {
        # If a package exists, it is because there is something to install.
        bail "Unknown package product '$package_product'"
    }

    default_archive() {
        local out=$ARCHIVE_DIR/$SYSTEM_KEY/$package_archive
        ! [ -f $out ] || return 0
        mkdir -p $ARCHIVE_DIR/$SYSTEM_KEY
        stage "Archiving $package_archive"
        tar --owner=0 --group=0 --numeric-owner -cJf $out -C $package_install_dir .
        # Merge-order manifest: extraction order matters for the handful of
        # files more than one package installs (busybox's symlink farm vs.
        # util-linux/systemd's real binaries overwriting it) — record each
        # package's tarball once, in the order it was archived, so a from-
        # scratch reconstruction (or a guest doing its own unarchiving) can
        # reproduce that order with no other bookkeeping.
        grep -qxF "$package_archive" $ARCHIVE_DIR/$SYSTEM_KEY/ORDER 2>/dev/null \
            || echo "$package_archive" >> $ARCHIVE_DIR/$SYSTEM_KEY/ORDER
    }

    default_merge() {
        stage "Merging $package_archive"
        # A prior merge's own output can be read-only by design (e.g.
        # ca-certificates' 0444 trust bundle, util-linux's 0444 man pages)
        # — plain `tar x` opens the destination for writing, which a
        # read-only file refuses even to its own owning uid, breaking the
        # ROLLOUT/re-run case specifically (an already-merged tree). chmod
        # always succeeds for files we own regardless of their current
        # mode, so this reliably clears the way; the tarball's own mode
        # bits (also 0444) are reapplied right after by the extraction
        # itself, so the end state is identical to a from-empty extraction.
        #
        # Scoped to exactly the paths this package is about to (re-)write,
        # NOT a blanket recursive chmod of the whole merge dir: with
        # package_merge_dir=/ (guest phase — see guest_build_env) an
        # unscoped `chmod -R u+w /` would walk the ENTIRE guest
        # filesystem, including the 9p-mounted host project at /mnt/lfs —
        # silently altering host file modes as a side effect of installing
        # one package. List the package's own paths — from the archive
        # normally, or from the stage dir itself in a tool-less guest,
        # where no archive exists (see the merge step below) — and chmod
        # only the ones that already exist in the merge dir; paths the
        # tarball is about to newly introduce need no chmod at all. Also
        # better for the container case: a full-tree chmod was always more
        # than any single package needed.
        if ! _guest_has_archive_tools; then
            (cd $package_install_dir && find . -mindepth 1)
        else
            tar tf $ARCHIVE_DIR/$SYSTEM_KEY/$package_archive
        fi | while IFS= read -r path; do
            path=${path#./}
            path=${path%/}
            # Skip both "" and "." (the top-level dir entry itself, spelled
            # either way depending on tar/find implementation) — never
            # chmod package_merge_dir's own root; only its contents.
            if [ -n "$path" ] && [ "$path" != "." ] && [ -e "$package_merge_dir/$path" ]; then
                chmod u+w "$package_merge_dir/$path" 2>/dev/null || true
            fi
        done

        if ! _guest_has_archive_tools; then
            # Tool-less-guest fallback (before the delivered tar+xz
            # tarballs are unarchived into it): no tarball exists to
            # extract (the archive step above was skipped too — see
            # _install), so copy the stage dir straight into the live
            # system with a plain tar pipe instead — busybox tar handles
            # plain (uncompressed) tar fine as both source and sink. Full
            # parity with the archive-extracting path below — and the
            # continuous self-test an extracted tarball ordinarily proves —
            # returns once the guest has a real tar+xz.
            tar -C $package_install_dir -cf - . | tar -C $package_merge_dir -xf -
        else
            # Extract the just-created tarball itself, rather than cp-ing
            # the stage dir directly: every build then continuously proves
            # the tarball is complete and correct, since it's literally
            # what lands in the merged tree. tar overwrites existing files
            # by default, so merging in package order reproduces the
            # pre-inversion tree exactly (see the ORDER manifest above for
            # why order matters). Guest phase reaches here too once
            # _guest_has_archive_tools is true — the guest's own GNU tar
            # extracts its own guest-local ARCHIVE_DIR tarball exactly like
            # the container extracts archive/$SYSTEM_KEY's.
            tar xf $ARCHIVE_DIR/$SYSTEM_KEY/$package_archive -C $package_merge_dir
        fi
    }

    patch_source() {
        local url=$1
        # Expected hash "algo:hexdigest" (package_source_hash form).
        # Required: patches come from the LFS book's *development* patch
        # dir, whose contents are regenerated in place, so an unverified
        # fetch here is the one download path that could silently apply
        # changed bytes.
        local hash=$2
        local file=${url##*/}
        mkdir -p $DOWNLOAD_DIR
        [ -f $DOWNLOAD_DIR/$file ] || fetch_url "$url" "$DOWNLOAD_DIR"
        verify_hash "$DOWNLOAD_DIR/$file" "$hash"
        # Idempotent per source extraction: apply once, stamp, skip on
        # re-invocation. $package_source_dir is SHARED across SYSTEM_KEYs
        # (not per-key), so without this a second key's build re-runs the
        # patch against an already-patched tree — "Reversed (or previously
        # applied) patch detected", which `patch -N` reports by EXITING
        # NON-ZERO (hunks ignored), failing prepare(). The stamp lives
        # with the extracted source, so a fresh re-extraction (new tarball)
        # correctly re-patches.
        local stamp=$package_source_dir/.patched-$file
        if [ -f "$stamp" ]; then
            echo "patch $file (done)"
        else
            # Portable across GNU patch (container) and busybox's patch
            # applet (guest-phase builds use busybox patch; see
            # package/patch.sh): busybox's patch has no -d and needs "-p N"
            # as two tokens, not GNU's combined "-Np1" — a subshell cd
            # achieves -d's effect portably, and both accept -N and -p 1
            # as separate flags.
            ( cd $package_source_dir && patch -N -p 1 -i $DOWNLOAD_DIR/$file )
            touch "$stamp"
        fi
    }

    . $PACKAGE_DIR/$package_name.sh

    case ${package_source:-none} in
        https://*.tar.*|https://*.tgz)
            ;;
        https://github.com*|https://git.*)
            if [ -z "${package_branch:-}" ]; then
                package_branch_file=$WORK_DIR/.$package_name-branch
                if ! [ -s $package_branch_file ]; then
                    mkdir -p $(dirname $package_branch_file)
                    git_default_branch $package_source > $package_branch_file
                fi
                package_branch=$(cat $package_branch_file)
            fi
            : ${package_version:=$package_branch}
            ;;
        none)
            ;;
    esac

    : ${package_release:=$package_name${package_variant:+-$package_variant}-$package_version${package_revision:+-$package_revision}}
    : ${package_files_dir:=$PACKAGE_DIR/$package_name}
    : ${package_source_dir:=$SOURCE_DIR/$package_name-$package_version}
    : ${package_work_dir:=$WORK_DIR/$package_release}
    : ${package_build_dir:=$package_work_dir/build/$package_component}
    : ${package_install_dir:=$package_work_dir/install/$package_component}
    if [ "$package_name" = "$package_component" ]; then
        : ${package_product:=$package_name}
        : ${package_deliverable:=$package_release}
    else
        : ${package_product:=$package_name#$package_component}
        : ${package_deliverable=$package_release-$package_component}
    fi
    : ${package_archive=$package_deliverable.tar.xz}
}
