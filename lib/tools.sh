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

    # --- Cross Toolchain Pass 1 (throwaway) ------------------
    (
        readonly package_variant=pass1
        readonly package_install_dir=/
        readonly prefix=$TOOL_DIR
        readonly sysroot=$TOOL_DIR
        readonly build_sysroot=$TOOL_DIR

        # Cross-assembler and linker.
        gprofng=no werror=no new_dtags=yes default_hash_style=gnu install binutils

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

    readonly package_variant=tools

    package_install_dir=$TOOL_DIR
    prefix=/usr

    # Linux kernel headers to build glibc.
    install linux#headers

    # GNU C library: the glibc that all toolchain binaries will link against.
    # Lives under TOOL_DIR/usr (like real LFS's $LFS/usr), not TOOL_DIR itself:
    # its own absolute self-references (e.g. the libc.so linker script) are
    # prefix-relative, and get sysroot-prefixed by TOOL_DIR again at link time.
    # If prefix were TOOL_DIR too, that would double up the path.
    nscd=no kernel=5.10 werror=no install glibc

    # Verify the cross-compiler references our glibc dynamic linker.
    echo 'int main(){}' | $TOOL_DIR/bin/$target-gcc -x c - -v -Wl,--verbose
    readelf -l a.out | grep -q ld-linux || bail "Cross-compiler does not use glibc ld"
    rm -f a.out

    # Bake the real (TOOL_DIR-relative) dynamic linker path and rpath into
    # every remaining binary at link time, rather than patchelf-ing it in
    # after the fact — patchelf can safely add an rpath, but growing an
    # already-linked PT_INTERP to a much longer string forces it to split
    # the ELF's leading segment, which it does incorrectly for larger
    # binaries (marks the split-off segment non-executable, crashing
    # anything whose .plt/.init ends up there).
    _tools_set_rtld_ldflags

    # C++ standard library (cross-compiled into TOOL_DIR/usr, same reasoning as glibc above).
    libstdcxx_pch=no install gcc#libstdc++

    # --- Temporary tools (glibc-linked, relocatable) ---------------

    # --build must be explicit: with only --host given, autoconf sets
    # cross_compiling=maybe and falls back to actually running a test
    # binary. Since target and build are the same architecture here,
    # that test binary runs "successfully" against the host's own libc,
    # so cross_compiling is wrongly resolved to "no" — and packages then
    # try to run their (incompatible, newer-glibc) freshly built binaries
    # directly, e.g. coreutils' man-page generation via help2man.
    readonly build=$(cc -dumpmachine)
    readonly host=$target

    # pkgconf's own compiled-in default search path is the literal
    # /usr/lib/pkgconfig (from its own --prefix=/usr at build time — it has
    # no notion of TOOL_DIR as a DESTDIR), so left alone it looks in this
    # container's real /usr instead of TOOL_DIR/usr. Needed by e.g. wget's
    # configure to find openssl.
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

    # Needed by the kernel's own `make headers_install` — it shells out to
    # rsync to copy sanitized headers, and the scratch phase has no host
    # PATH fallback to borrow one from.
    install rsync

    # wget (and its openssl/zlib deps), so the self-hosted scratch/system
    # phases can fetch their own package sources over HTTPS — bootstrap
    # stays minimal and never pre-fetches anything on their behalf.
    install zlib
    install openssl
    install pkgconf
    install wget

    readonly sysroot=$TOOL_DIR
    readonly build_sysroot=$TOOL_DIR

    # Binutils pass 2: native (glibc-linked) linker/assembler.
    gprofng=no werror=no install binutils

    # GCC pass 2: native compiler for the target (glibc-linked, Canadian cross).
    glibc_version=$(version glibc) languages=c,c++ \
    shared=yes threads=yes libstdcxx=yes \
    fixincludes=no \
    libatomic=no libgomp=no libquadmath=no libsanitizer=no libssp=no libvtv=no \
    install gcc

    _tools_relocate

    # TOOL_DIR is a named volume, invisible to `docker build`; stage our
    # own already-built bash where Dockerfile.scratch's COPY can reach it.
    mkdir -p $SCRATCH_INIT_DIR
    cp -v $TOOL_DIR/usr/bin/bash $SCRATCH_INIT_DIR/sh

    # Empty placeholder Dockerfile.scratch's COPY --chown uses to seed the
    # install volume's ownership — see the comment there.
    mkdir -p $SCRATCH_INIT_DIR/empty
}

build_tools() {
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

    readonly package_install_dir=$TOOL_DIR
    readonly prefix=/usr
    readonly nls=no

    install gettext
    install bison
    install python

    # Needed to build systemd itself in the later `system build` step. Real
    # LFS builds these inside its chroot as ordinary chapter 8 packages
    # (alongside systemd, using its own chroot's Python) since it doesn't
    # strip build-only tooling back out of the final system; this project
    # does, so they get the same build-time-only treatment as bison/gettext
    # /python above instead of landing in INSTALL_DIR.
    install ninja
    install meson
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
}

# Every remaining binary this session builds is host=$target and should
# already carry a correct, TOOL_DIR-relative interpreter/rpath (see the
# call site in tools_bootstrap). This just exports the LDFLAGS that make
# that happen, so tools_build can use the same fix for `install gettext`.
_tools_set_rtld_ldflags() {
    local rtld=$(find $TOOL_DIR/usr/lib -maxdepth 1 -name 'ld-linux-*.so.*' | head -1)
    [ -n "$rtld" ] || bail "Cannot find dynamic linker built by glibc"
    # usr/lib64 too: gcc's own build puts libstdc++ there by default on this
    # target regardless of multilib=no, unlike every other TOOL_DIR package
    # (glibc included), which all land under plain usr/lib.
    export LDFLAGS="-Wl,--dynamic-linker=$rtld -Wl,-rpath,$(dirname $rtld) -Wl,-rpath,$TOOL_DIR/usr/lib64"
}

# Safety net for anything under TOOL_DIR/usr that didn't pick up
# tools_set_rtld_ldflags at link time (e.g. it was built before that call,
# or its build system drops LDFLAGS) and so still has the bootstrap
# container's default rpath. Only ever adds an rpath — never touches
# PT_INTERP after the fact, since growing it is what corrupts segment
# layout (see tools_set_rtld_ldflags).
#
# TOOL_DIR/bin (pass1 binutils/gcc) is deliberately excluded: it's a
# throwaway, host-native toolchain used only to bootstrap glibc/pass2 here
# in the bootstrap container, and is linked against the host's own glibc —
# relocating it would break it for no benefit, since it's not part of the
# self-contained toolchain the `scratch` image runs.
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
        patchelf --set-rpath $lib_dir "$f"
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
