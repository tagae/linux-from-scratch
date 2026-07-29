# Canadian Cross
# --------------
#
# The system on which the tools are being built is called the build system.
# The system on which the tools will run is called the host system.
# The system for which the resulting cross compiler generates code is called the target system.
#
# When build == host == target, we have a native toolchain.
# When build == host != target, we have a cross toolchain.
# When build != host == target, we have a cross-native toolchain.
# When build != host != target, we have a canadian toolchain.

# See https://www.airs.com/ian/configure/configure_5.html

tools() {
    case "${1:-help}" in
        bootstrap) bootstrap_tools ;;
        build)     build_tools ;;
        help)
            echo "Usage: $(basename "$0") tools <bootstrap|build>"
            if [ $# -eq 1 ]; then exit 0; else exit 1; fi
            ;;
        *) bail "Unknown command '$1'" ;;
    esac
}

bootstrap_tools() {
    readonly nls=no
    readonly multilib=no

    case "$(uname -m)" in
        aarch64|arm64)
            readonly native_arch=arm64
            readonly native_target=aarch64-native-linux-gnu
            ;;
        armv6l)
            readonly native_arch=arm
            readonly native_target=arm-native-linux-gnueabihf
            ;;
        x86_64)
            readonly native_arch=x86;
            readonly native_target=x86_64-native-linux-gnu
            ;;
        *) bail "Unsupported native architecture $(uname -m)" ;;
    esac

    # --- Cross Toolchain Pass 1 ------------------

    (
        readonly package_variant=pass1-$target
        readonly package_install_dir=/
        readonly prefix=$TOOL_DIR
        readonly sysroot=$TOOL_DIR/$target
        readonly build_sysroot=$TOOL_DIR/$target

        # Cross-assembler and linker.
        gprofng=no werror=no new_dtags=yes default_hash_style=gnu install binutils

        _build_gcc_prereqs
        exit 0

        # Minimal C cross-compiler to build glibc.
        glibc_version=$(version glibc) \
        newlib=yes headers=no \
        default_pie=yes default_ssp=yes \
        fixincludes=no \
        shared=no threads=no \
        libatomic=no libgomp=no libquadmath=no libssp=no libvtv=no libstdcxx=no\
        languages=c,c++ \
        install gcc
    )

    exit 0
    _os_is_build_host || _bootstrap_build_host

    # --- Per-target sysroot (one per distinct $target
    # glibc: never executed —only ever linked/read against by pass2 below.
    (
        readonly package_variant=$target
        package_install_dir=$TOOL_DIR/$target
        prefix=/usr
        unset LDFLAGS

        install linux#headers
        nscd=no enable_kernel=5.10 werror=no install glibc
    )

    # --- Cross Toolchain Pass 2 (the real, shipped cross-compiler) --
    # Genuine cross-compiler: no --host, only --target=$target (the
    # default cross_target in gcc.sh/binutils.sh), so binaries are
    # $target-prefixed (e.g. aarch64-scratch-linux-gnu-gcc) and execute on
    # the build host (this scratch container, via the native glibc/
    # libstdc++ above — inherited LDFLAGS bakes that in) while emitting
    # $target code. --with-sysroot bakes in the per-target sysroot above,
    # so $target-gcc alone finds the right target glibc/headers with no
    # extra flags at build_system() time.
    (
        readonly package_variant=$target
        readonly package_install_dir=/
        prefix=$TOOL_DIR
        readonly sysroot=$TOOL_DIR/$target
        readonly build_sysroot=$TOOL_DIR/$target

        gprofng=no werror=no install binutils

        _build_gcc_prereqs

        _tools_install_full_gcc
    )

    # Verify the cross-compiler references our glibc dynamic linker.
    echo 'int main(){}' | $TOOL_DIR/bin/$target-gcc -x c - -v -Wl,--verbose
    readelf -l a.out | grep -q ld-linux || bail "Cross-compiler does not use glibc ld"
    rm -f a.out

    _os_is_build_host || _bootstrap_stage_for_scratch
}

# Builds gcc's prerequisite math libraries.
_build_gcc_prereqs() {
    install gmp
    exit 0
    CPPFLAGS="-I$TOOL_DIR/include ${CPPFLAGS:-}" \
    LDFLAGS="-L$TOOL_DIR/lib ${LDFLAGS:-}" \
    install mpfr
    CPPFLAGS="-I$TOOL_DIR/include ${CPPFLAGS:-}" \
    LDFLAGS="-L$TOOL_DIR/lib ${LDFLAGS:-}" \
    install mpc
    # These variables feed gcc.sh's own "${gmp:+--with-gmp=$gmp}", etc.
    gmp=$TOOL_DIR
    mpfr=$TOOL_DIR
    mpc=$TOOL_DIR
    LDFLAGS="-Wl,-rpath,$TOOL_DIR/lib ${LDFLAGS:-}"
    export LDFLAGS
}

_bootstrap_build_host() {
    # --- Native runtime toolchain
    # build-host arch, shared by every target platform
    (
        readonly package_variant=tools
        readonly cross_target=
        package_install_dir=$TOOL_DIR
        prefix=/usr

        cross_arch=$native_arch install linux#headers
        nscd=no enable_kernel=5.10 werror=no install glibc
    )

    # Bake the real (TOOL_DIR-relative) dynamic linker path and rpath into
    # every remaining native binary at link time. Exported here in the outer
    # (non-subshell) scope, *before* pass1-native builds below, so it
    # picks up the correct rpath at link time instead —every native
    # build below inherits this export; a subshell's own export can't
    # propagate back out or sideways.
    _tools_set_rtld_ldflags

    # --- Cross Toolchain Pass 1, native (throwaway) ------------------
    # This is NOT a pass-1-style (newlib, no libc) build, despite the
    # name — it mirrors PASS 2 below instead (real libc, shared=yes,
    # libstdcxx=yes), just targeting the build host's own triple instead
    # of $target. Real pass 1 is newlib-based specifically because no
    # target glibc exists yet when it builds (it's what bootstraps that
    # glibc in the first place) — that constraint doesn't apply here: the
    # native glibc above already exists by the time this builds, so this
    # can (and must) be a genuine, fully-capable compiler from the start,
    # sysroot-linked against it — a newlib-based one, tried first, cannot
    # link a normal hosted C++ program at all (confirmed empirically: its
    # own separately-built libstdc++ hit "Link tests are not allowed
    # after GCC_NO_EXECUTABLES" downstream, since a no-libc compiler
    # genuinely can't satisfy basic hosted-program symbol references,
    # regardless of how the build/host/target triples are set).
    #
    # Building it this way (libstdcxx=yes) also sidesteps the original
    # reason this exists at all: gcc's own build process always compiles
    # libgcc/libstdc++ using the *just-built* stage-1 compiler (that's
    # true regardless of --disable-bootstrap, which only controls whether
    # gcc rebuilds *itself* multiple times) — so this libstdc++ is built
    # by a genuinely matching-version (16.1.0) compiler automatically,
    # with no separate standalone libstdc++ step or CC/CXX override
    # needed at all. Debian's system g++ (14.2.0) only ever compiles
    # gcc's own driver/cc1/cc1plus sources here — not gcc 16.1.0's own
    # <atomic>, which is what made it fail as a *matching-version*
    # compiler stand-in earlier ("'constexpr' constructor does not have
    # empty body").
    #
    # Same install layout as real pass 1 above (package_install_dir=/,
    # prefix=$TOOL_DIR, landing directly in TOOL_DIR/bin) rather than the
    # DESTDIR-staged TOOL_DIR/usr convention everything else here uses —
    # confirmed empirically that prefix=/usr (an already-populated, real
    # path in this bootstrap container) makes some of gcc's own build-time
    # link-tests behave inconsistently, unlike prefix=$TOOL_DIR (nothing
    # pre-existing there to confuse a test link against). Unlike real
    # pass 1 (genuinely throwaway, never runs outside this container),
    # this DOES need to be executable from the scratch container too —
    # built *after* the native glibc + _tools_set_rtld_ldflags above, so
    # (unlike everything else here) it picks up the correct rpath at link
    # time rather than needing it patched in after the fact.
    (
        readonly package_variant=pass1-$native_target
        readonly package_install_dir=/
        prefix=$TOOL_DIR
        readonly cross_target=$native_target
        readonly sysroot=$TOOL_DIR
        readonly build_sysroot=$TOOL_DIR

        gprofng=no werror=no install binutils

        _tools_install_full_gcc
    )

    # Bare "gcc"/"cc"/"as"/"ld"/etc: what the temporary tools further down,
    # build_tools(), and every hand-rolled-Makefile package elsewhere
    # (btrfs-progs, kpartx, libaio, ...) that hardcodes a bare CC=gcc
    # actually compile with. Without this, nothing in the (otherwise
    # completely empty) scratch container could compile anything at all.
    #
    # Symlinked to pass1-native's own $native_target-prefixed tools
    # (already a genuine, fully-capable, working compiler, built above)
    # rather than building a whole second, separately-named "native"
    # gcc/binutils from scratch — a plain native build (host=build=target,
    # all the same string, no --host/--target override at all) makes
    # gcc's own top-level configure auto-select a multi-stage bootstrap
    # build instead of the single, already-sufficient compile above. This
    # is simpler and just as correct: anything that would have configured
    # a genuinely native gcc anyway just gets its bare names for free.
    for _tool in gcc cc g++ c++ cpp gcov gcov-tool gcc-ar gcc-nm gcc-ranlib \
                 as ld ld.bfd ar nm objcopy objdump ranlib strip \
                 addr2line readelf size strings; do
        [ -x "$TOOL_DIR/bin/$native_target-$_tool" ] || continue
        ln -sfv "$TOOL_DIR/bin/$native_target-$_tool" "$TOOL_DIR/usr/bin/$_tool"
    done
    unset _tool

    # Stage the native C++/GCC runtime into $TOOL_DIR/usr/lib. pass1-native
    # is built with --target=$native_target, so gcc installs its target
    # runtime (libstdc++.so.6, libgcc_s.so.1) under $TOOL_DIR/$native_target/
    # lib64 — a compiler-internal path found at *link* time but on nobody's
    # *runtime* search path. The scratch container is FROM scratch (no
    # /etc/ld.so.conf, no default /usr/lib population), so every binary
    # there resolves its libraries purely via the rpath baked in by
    # _tools_set_rtld_ldflags, which points at $TOOL_DIR/usr/lib. Copying
    # the C++ runtime there (next to glibc) is what lets a just-built C++
    # program actually run in scratch — e.g. ninja's bootstrap, which
    # compiles ./ninja and then executes it. cp -a preserves the soname
    # symlink chain (libstdc++.so.6 -> libstdc++.so.6.0.NN).
    cp -av $TOOL_DIR/$native_target/lib64/libstdc++.so.6* \
           $TOOL_DIR/$native_target/lib64/libgcc_s.so.1 \
           $TOOL_DIR/usr/lib/

    # --- Temporary tools (glibc-linked, native, relocatable) --------
    #
    # The scratch container's own userspace (bash as /bin/sh, coreutils,
    # sed, tar, ...) — build-host-native by definition, same reasoning as
    # the native toolchain above. Built here rather than in build_tools()
    # because Dockerfile.scratch needs bash already staged in
    # SCRATCH_INIT_DIR before build_tools() can even run (it executes
    # inside the scratch container, which needs a working /bin/sh first).
    (
        readonly package_variant=tools
        package_install_dir=$TOOL_DIR
        prefix=/usr

        # Compiled through pass1-native's own $native_target-gcc (sysroot=
        # $TOOL_DIR), NOT this Debian container's bare "gcc". host=
        # $native_target routes every autoconf package's compiler to it;
        # zlib/openssl/bzip2 (hand-rolled Makefiles, no --host) read
        # cross_target/cross_arch for the same prefixed names. Going
        # through the sysroot'd compiler is what makes $TOOL_DIR/usr/
        # {include,lib} its *own* system paths, so headers and libraries
        # installed here (zlib.h, libssl, ...) resolve with no extra -I/-L,
        # and glibc's ld-script stubs (libc.so/libm.so, whose internal refs
        # are bare /usr/lib/... paths) get sysroot-prefixed to $TOOL_DIR
        # automatically — none of which holds for Debian's bare gcc, which
        # is what forced the pkg-config/ldscript/-I workarounds this
        # replaces. Same shape as the per-target cross build below, just
        # aimed at the build host's own triple.
        #
        # build must be explicit: with only --host, autoconf sets
        # cross_compiling=maybe and falls back to running a test binary,
        # which (same arch as build) runs fine against the host libc and
        # wrongly resolves cross_compiling=no — packages then execute their
        # freshly-built (newer-glibc) binaries directly, e.g. coreutils'
        # help2man man-page generation.
        readonly build=$(cc -dumpmachine)
        readonly host=$native_target
        readonly cross_target=$native_target
        readonly cross_arch=$native_arch

        # pkgconf's own compiled-in default search path is the literal
        # /usr/lib/pkgconfig (from its own --prefix=/usr at build time — it
        # has no notion of TOOL_DIR as a DESTDIR), so left alone it looks
        # in this container's real /usr instead of TOOL_DIR/usr. Needed by
        # e.g. wget's configure to find openssl.
        export PKG_CONFIG_LIBDIR=$TOOL_DIR/usr/lib/pkgconfig

        install m4
        package_install_dir=/ prefix=$TOOL_DIR install ncurses#tic
        shared=yes normal=no cxx_shared=yes debug=no ada=no stripping=no install ncurses
        curses=no install bash
        install_program=hostname no_install_program=kill,uptime install coreutils
        install diffutils
        install file#native
        install file
        localstatedir=$TOOL_DIR/var/lib/locate install findutils
        install gawk
        install grep
        install gzip
        install make
        install patch
        install sed
        install tar
        install xz
        # tar shells out to this to decompress .tar.bz2 sources (e.g. busybox).
        install bzip2

        # Needed by the kernel's own `make headers_install` — it shells out
        # to rsync to copy sanitized headers, and the scratch phase has no
        # host PATH fallback to borrow one from.
        install rsync

        # wget (and its openssl/zlib deps), so the self-hosted scratch/system
        # phases can fetch their own package sources over HTTPS — bootstrap
        # stays minimal and never pre-fetches anything on their behalf.
        install zlib
        install openssl
        install pkgconf
        install wget
    )

    # --- CA trust store: build our own bundle here, in bootstrap -------
    # Generate the CA certificate bundle from Mozilla's certdata.txt now, in
    # the bootstrap (Debian) container, so it exists BEFORE the scratch phase
    # runs — letting that phase verify TLS against OUR OWN trust store from
    # its very first download (eating our own dog food) instead of a copy of
    # Debian's bundle. The chain's own sources download verified by Debian's
    # bundle (this phase's SSL_CERT_FILE), exactly as every other bootstrap
    # source already does — Debian's certs authenticate the downloads, but
    # Debian's bundle *file* is never used as the scratch phase's trust anchor.
    #
    # openssl (make-ca's crypto backend) and pkgconf (p11-kit's meson
    # dependency probe) come from the temp-tools subshell above; python3 for
    # meson/ninja is the Debian container's own (it ships no ninja/meson, so
    # build them here — they are also build_tools() members, stamp-shared, so
    # that later call fast-paths). CC/CXX are pointed explicitly at the native
    # cross-compiler: unlike the scratch phase, bare `gcc` here resolves to
    # Debian's own (PATH order), which would link p11-kit's `trust` against
    # Debian glibc and leave it unable to run in the FROM-scratch container.
    # meson/ninja honor CC/CXX from the environment; autoconf (libffi/
    # libtasn1) via --host below.
    (
        readonly package_variant=tools
        package_install_dir=$TOOL_DIR
        prefix=/usr

        # Debian's own build triple — computed via bare `cc` BEFORE the CC
        # override below (which would otherwise make it report $native_target).
        readonly build=$(cc -dumpmachine)
        readonly host=$native_target
        export CC=$native_target-gcc CXX=$native_target-g++
        export PKG_CONFIG_LIBDIR=$TOOL_DIR/usr/lib/pkgconfig
        # Mirror build_tools()' env: glibc's compiled-in gconv path is this
        # container's real /usr/lib/gconv; point it at our own. (No modules are
        # actually installed there, so make-ca's UTF-8 cert labels resolve via
        # glibc's built-in converters — this only prevents a stray lookup in
        # the wrong tree.)
        export GCONV_PATH=$TOOL_DIR/usr/lib/gconv

        install ninja
        install meson
        install libffi
        install libtasn1
        install p11-kit
        install make-ca
        install ca-certificates
    )
}

# Container-only post-processing once the cross-compiler is built:
# patchelf-based rpath relocation (patchelf, like the rest of the build
# host, only exists in the bootstrap container; a guest's pass2 gcc
# already gets a correct rpath at link time from _tools_set_rtld_ldflags,
# itself only exported inside _bootstrap_build_host above, so there is
# nothing left to relocate in guest phase anyway) and staging the
# toolchain/CA bundle where Dockerfile.scratch's build (work/certs,
# SCRATCH_INIT_DIR) can reach them. A guest has no scratch container to
# stage for, so bootstrap_tools() calls this only outside guest phase too.
_bootstrap_stage_for_scratch() {
    _tools_relocate

    # Stage our own generated CA bundle (built by the cert chain above from
    # Mozilla's certdata.txt, never Debian's) where the scratch phase's
    # SSL_CERT_FILE points (see lfs). $WORK_DIR is the shared `work` volume —
    # mounted in both the bootstrap and scratch containers — so a copy here
    # reaches the scratch phase with no extra mount, the same way the toolchain
    # itself does. Kept separate from the in-tree $TOOL_DIR/etc/ssl store the
    # ca-certificates package installs, so the build's trust anchor is one
    # explicit, dedicated file (cf. the staged bash in $SCRATCH_INIT_DIR).
    # -f: make-ca leaves the bundle read-only (0444), so a re-run (another
    # `make tools`) must be able to replace an existing, unwritable copy —
    # cp -f removes it and retries rather than failing with EACCES.
    mkdir -p $WORK_DIR/certs
    cp -fv $TOOL_DIR/etc/ssl/certs/ca-certificates.crt $WORK_DIR/certs/ca-certificates.crt

    # TOOL_DIR is a named volume, invisible to `docker build`; stage our
    # own already-built bash where Dockerfile.scratch's COPY can reach it.
    mkdir -p $SCRATCH_INIT_DIR
    cp -v $TOOL_DIR/usr/bin/bash $SCRATCH_INIT_DIR/sh

    # Empty placeholder Dockerfile.scratch's COPY --chown uses to seed the
    # install volume's ownership — see the comment there.
    mkdir -p $SCRATCH_INIT_DIR/empty
}

build_tools() {
    # Guest phase never calls this: the build_tools() output (bison/flex/
    # perl/kmod/util-linux/btrfs-progs/kpartx/...) is exactly the tool set
    # a booted LFS guest already carries as part of its own system (see
    # docs/design/guest-cross-builder.md) — nothing to (re)build. A stray
    # invocation is a clean no-op, not an attempt to run patchelf-based
    # relocation (below) against a container that doesn't exist here.
    if _os_is_build_host; then
        echo "tools build: this system already carries its own tool set (skipping)"
        return 0
    fi

    # No _tools_relocate call here: it shells out to patchelf, which only
    # exists in the bootstrap container. Everything built in this phase
    # already gets a correct interpreter/rpath at link time from
    # _tools_set_rtld_ldflags, so the patchelf safety net isn't needed.
    _tools_set_rtld_ldflags

    # The scratch image has no /tmp (see Dockerfile.scratch); TMPDIR points
    # here instead, but nothing else creates it.
    mkdir -p "${TMPDIR:-/tmp}"

    # glibc's own compiled-in default gconv module path is the literal
    # /usr/lib/gconv (this container's real root, not TOOL_DIR-relative) —
    # same story as PKG_CONFIG_LIBDIR and BISON_PKGDATADIR. Without this,
    # iconv_open() fails for anything beyond a few built-in fast-path
    # charsets (plain ASCII/UTF-8 works, ISO-8859-1 etc. doesn't), which
    # in turn makes gettext's own configure conclude iconv is broken and
    # build msgfmt without iconv support at all.
    export GCONV_PATH=$TOOL_DIR/usr/lib/gconv

    # pkgconf's own compiled-in default search path is the literal
    # /usr/lib/pkgconfig — same story as GCONV_PATH above. This is a
    # separate `./lfs tools build` invocation from bootstrap_tools, which
    # sets the same export for its own process; it doesn't carry over.
    export PKG_CONFIG_LIBDIR=$TOOL_DIR/usr/lib/pkgconfig

    readonly package_variant=tools
    readonly package_install_dir=$TOOL_DIR
    readonly prefix=/usr
    readonly nls=no

    install gettext
    install bison
    # optimizations=no: --enable-optimizations (PGO) fails at the profiling
    # run here (libpython3.14.so's gcov instrumentation doesn't resolve
    # __gcov_indirect_call under our _tools_set_rtld_ldflags-injected
    # LDFLAGS) — moot anyway, since Python is only build-time tooling here
    # and never actually runs as the shipped system's own interpreter.
    optimizations=no install python

    # Needed to build systemd itself in the later `system build` step. Real
    # LFS builds these inside its chroot as ordinary chapter 8 packages
    # (alongside systemd, using its own chroot's Python) since it doesn't
    # strip build-only tooling back out of the final system; this project
    # does, so they get the same build-time-only treatment as bison/gettext
    # /python above instead of landing in INSTALL_DIR.
    # Also built (earlier) by bootstrap_tools' cert chain, so these fast-path
    # here; kept because the later systemd build genuinely depends on them.
    install ninja
    install meson

    # NOTE: the CA trust store (libffi → libtasn1 → p11-kit → make-ca →
    # ca-certificates) is built in bootstrap_tools(), not here — our own
    # bundle must exist before this phase's very first download so fetch_url
    # (lib/base.sh) can verify TLS against it from the start. See the cert
    # chain comment there. bootable-{systemd,busybox}.sh separately require()
    # ca-certificates into each target tree.

    install gperf

    # systemd's meson.build itself requires python3's jinja2 module (used
    # to generate some templated files at build time). Our python3 has no
    # ssl module (no openssl support configured in), so pip can't fetch
    # from PyPI — these are pure Python, so just place them directly like
    # meson above.
    install markupsafe
    install jinja2

    # Needed by the kernel's own Kconfig tooling (lexer.lex.c generation)
    # and kernel/bounds.s's timeconst.h generation, when building linux for
    # the system phase.
    install flex
    install bc

    # Needed by the kernel's own PERLASM steps (e.g. lib/crypto/arm64/
    # sha256-core.S) when building linux for the system phase.
    install perl

    # depmod: the kernel's own `make modules_install` (linux.sh, system
    # phase) runs it automatically via scripts/depmod.sh whenever one is
    # found on PATH, to index the modules it just installed (modules.dep/
    # modules.alias/etc — without them modprobe/systemd can't resolve a
    # module by name even though the .ko file is right there on disk).
    # Genuinely build-host-native here, same reasoning as libblkid/btrfs-
    # progs/kpartx below: depmod only ever *reads* the target's .ko files
    # to build the index, it doesn't need to run on the target itself, and
    # INSTALL_DIR's own kmod is target-native (built with host=$target in
    # build_system()) so it can't run here.
    manpages=no install kmod

    # libblkid (for btrfs-progs below) plus fallocate/losetup/sfdisk/mount
    # /umount/mountpoint, needed by `image build` — genuinely build-host-
    # native here (unlike reusing INSTALL_DIR's own copies, which would be
    # target-native and break on any platform whose target architecture
    # isn't the build host's, e.g. pi0). package_variant=tools (set above)
    # already keeps this build's work dir/markers separate from
    # build_system()'s own `install util-linux` (which targets INSTALL_DIR,
    # no variant set).
    #
    # --disable-all-programs defaults *everything* (including libraries)
    # to disabled, only overridable by explicitly naming what to re-enable.
    # bindir/sbindir: TOOL_DIR has no merged-usr symlinks (that's an
    # INSTALL_DIR/system-files thing), so without these the programs would
    # land under plain bin/sbin, which isn't on PATH here.
    # makeinstall_chown=no: same as build_system()'s own util-linux call —
    # `chown root:root` on mount for setuid fails outright, no /etc/passwd
    # for "root" to resolve against.
    # makeinstall_setuid=no: without also disabling this, `make install`
    # still chmod u+s's mount/umount despite the chown above being skipped —
    # leaving them setuid to the *build* UID (not root). Executing a
    # setuid-to-non-root binary as real root then drops the effective UID
    # to that owner, so mount(2) genuinely runs unprivileged and fails with
    # "must be superuser" (confirmed via the file's owner/mode: mount was
    # -rwsr-xr-x owned by the build UID, not 0). We always invoke these
    # tools as genuine root already, so setuid serves no purpose here.
    all_programs=no libdir=/usr/lib bindir=/usr/bin sbindir=/usr/sbin \
    makeinstall_chown=no makeinstall_setuid=no \
    libblkid=yes libuuid=yes libmount=yes libfdisk=yes libsmartcols=yes \
    mount=yes fdisks=yes losetup=yes fallocate=yes mountpoint=yes \
        install util-linux

    # mkfs.btrfs and the btrfs CLI, needed by `image build` to format and
    # populate the root filesystem — never shipped, build/test-time only.
    install btrfs-progs

    # mkfs.fat, needed by `image build` to format the FAT boot partition of
    # the Pi image layout (the virt `single` layout has no boot partition
    # and never calls it) — never shipped, build/test-time only.
    install dosfstools

    # kpartx, needed by `image build` to expose the loop device's
    # partitions: losetup -P's own kernel-level partition scanning doesn't
    # reliably create the /dev/loopNpM device nodes inside a container (no
    # working udev/devtmpfs auto-population there), so we fall back to
    # kpartx's explicit device-mapper nodes instead. It only needs
    # libdevmapper, so build that (via lvm2, its own required dependency
    # is libaio) rather than the rest of LVM2's tools/daemon.
    install libaio
    install lvm2#device-mapper
    install multipath-tools#kpartx
}

# The full, real gcc build — shared verbatim by Cross Toolchain Pass 2
# (the shipped $target cross-compiler) and pass1-native (the build
# host's own compiler, which deliberately mirrors pass 2 rather than
# real pass 1's newlib/no-libc shape — see its call site for why).
# Everything scenario-specific (package_variant, prefix, sysroot,
# cross_target, the _build_gcc_prereqs handoff) is the caller's own
# subshell state.
_tools_install_full_gcc() {
    glibc_version=$(version glibc) languages=c,c++ \
    shared=yes threads=yes libstdcxx=yes \
    fixincludes=no \
    libatomic=no libgomp=no libquadmath=no libsanitizer=no libssp=no libvtv=no \
    install gcc
}

# Every native binary from here on (the temporary tools, build_tools()'s
# own output, and the cross-compilers' own executables) should carry a
# correct, TOOL_DIR-relative interpreter/rpath pointing at the native
# glibc/libstdc++ under TOOL_DIR/usr — see the call site in
# bootstrap_tools(). This just exports the LDFLAGS that make that happen,
# so build_tools() can use the same fix for `install gettext`.
_tools_set_rtld_ldflags() {
    local rtld=$(find $TOOL_DIR/usr/lib -maxdepth 1 -name 'ld-linux-*.so.*' | head -1)
    [ -n "$rtld" ] || bail "Cannot find dynamic linker built by glibc"
    # A single rpath at $TOOL_DIR/usr/lib (= $(dirname $rtld)) is enough:
    # glibc, and the native libstdc++/libgcc_s staged next to it after
    # pass1-native (see bootstrap_tools), all live there.
    #
    # Deliberately no -L$TOOL_DIR/lib here (tried it, reverted):
    # inside the *bootstrap* container specifically, that makes ld find
    # TOOL_DIR's own libc.so — a linker script whose internal references
    # are bare, root-relative paths (/usr/lib/libc.so.6), correct only
    # where /usr/lib is bind-mounted to TOOL_DIR (the scratch container),
    # not here, where /usr/lib is Debian's own multiarch tree. Broke even
    # bare "gcc"'s own build-time sanity check ("cannot find /usr/lib/
    # libc.so.6") for anything compiled inside the bootstrap container
    # with this exported. -rpath alone doesn't have this problem (it's
    # just a runtime hint, not a link-time search path).
    export LDFLAGS="-Wl,--dynamic-linker=$rtld -Wl,-rpath,$(dirname $rtld)"
}

# Safety net for anything under TOOL_DIR/usr that didn't pick up
# tools_set_rtld_ldflags at link time (e.g. it was built before that call,
# or its build system drops LDFLAGS) and so still has the bootstrap
# container's default rpath. Only ever adds an rpath — never touches
# PT_INTERP after the fact, since growing it is what corrupts segment
# layout (see tools_set_rtld_ldflags).
#
# Must be idempotent AND non-destructive: bootstrap_tools() runs it on
# every `make tools` (there's no marker gating the function itself), over a
# persistent volume that a *prior* run's build_tools() already populated —
# and a bare `--set-rpath X` *replaces*, so re-running would collapse
# already-correct richer rpaths down to just $lib_dir. That silently broke
# real binaries: perl (libperl.so lives in .../CORE, not $lib_dir) and
# kpartx/anything with a legitimately multi-dir rpath. So: skip files that
# already resolve via $lib_dir, and otherwise *append* $lib_dir to the
# existing rpath rather than overwriting it.
#
# TOOL_DIR/bin isn't scanned at all (only TOOL_DIR/usr is): pass1's
# binutils/gcc there are a throwaway toolchain used only to bootstrap the
# per-target sysroot glibc in the bootstrap container, linked against the
# host's own (Debian) glibc — relocating them would break them for no
# benefit, since they're not part of the self-contained toolchain the
# `scratch` image runs. Pass2's binutils/gcc also land in TOOL_DIR/bin,
# but need no relocation either: they're built after _tools_set_rtld_
# ldflags is already active, so they get the correct rpath baked in at
# link time already.
_tools_relocate() {
    stage "Relocating toolchain binaries under $TOOL_DIR/usr"

    local ld_so=$(find $TOOL_DIR/usr/lib -maxdepth 1 -name 'ld-linux-*.so.*' | head -1)
    [ -n "$ld_so" ] || bail "Cannot find dynamic linker to relocate against"
    local lib_dir=$(dirname $ld_so)

    # Excluded by name pattern directly in find: the dynamic linker itself
    # (both the soname in usr/lib and the usr/bin/ld.so convenience copy)
    # is self-referential and patchelf reliably corrupts it.
    # The `|| true` on each loop matters under `set -o errexit -o nounset`:
    # without it, the EOF-triggered nonzero return from the final `read`
    # aborts the whole script right there, silently (no error, no bail) —
    # even though a `while read` condition's exit status is normally
    # exempt from errexit.
    find $TOOL_DIR/usr \( -type f -perm -u+x -o -name '*.so' -o -name '*.so.*' \) \
        -not -name 'ld-linux-*.so.*' -not -name 'ld.so' -print |
    while IFS= read -r f; do
        [ "$(head -c4 "$f" 2>/dev/null | od -An -tx1 | tr -d ' \n')" = 7f454c46 ] || continue
        readelf -d "$f" 2>/dev/null | grep -q 'Dynamic section' || continue
        # Already reachable via $lib_dir? Leave it exactly as-is — this is
        # what makes re-runs idempotent and preserves richer rpaths.
        local cur=$(patchelf --print-rpath "$f" 2>/dev/null)
        case ":$cur:" in *":$lib_dir:"*) continue ;; esac
        # This tree also holds files build_tools() installed in a later,
        # separate invocation (TOOL_DIR is one persistent volume) — some of
        # those are deliberately read-only by their own package's
        # convention (e.g. perl's XS .so modules), which patchelf can't
        # open for writing otherwise.
        chmod -f u+w "$f"
        # Append, don't replace: keep any existing entries (e.g. perl's CORE).
        patchelf --set-rpath "${cur:+$cur:}$lib_dir" "$f"
    done || true

    # bail runs in this (non-subshell) context, not inside a `while read`
    # piped from find, so its exit actually stops the script — calling it
    # from inside such a subshell only exits that subshell.
    local corrupted=$(find $TOOL_DIR/usr \( -name 'ld-linux-*.so.*' -o -name 'ld.so' \) \
        -exec sh -c 'readelf -d "$1" 2>/dev/null | grep -q RUNPATH && echo "$1"' _ {} \;)
    [ -z "$corrupted" ] \
        || bail "Dynamic linker(s) were themselves relocated — this breaks them: $corrupted"

    return 0
}

# Tests whether the running system is an LFS build host.
_os_is_build_host() {
    gcc -dumpmachine 2>/dev/null | grep -q -- -scratch- \
        && [ ! -e "$TOOL_DIR/usr/bin/gcc" ]
}
