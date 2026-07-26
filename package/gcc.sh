# https://gcc.gnu.org/install/build.html

: ${package_version:=16.1.0}
: ${package_source:=https://ftpmirror.gnu.org/gcc/gcc-$package_version/gcc-$package_version.tar.xz}
: ${package_source_hash:=sha256:50efb4d94c3397aff3b0d61a5abd748b4dd31d9d3f2ab7be05b171d36a510f79}

fetch() {
    default_fetch
    local dependency
    for dependency in mpfr gmp mpc; do
        # Skip symlinking this dependency's source into the gcc tree when
        # the caller already points gcc at an external, prebuilt copy
        # (native-toolchain.sh: host=$target, --with-gmp/--with-mpfr/
        # --with-mpc — see prepare()) — mirrors the standard LFS-book
        # instruction to remove these symlinks once the version
        # requirements are satisfied some other way. This is NOT just
        # cosmetic/redundant-avoidance: gcc's own top-level configure
        # decides whether to configure+build EACH bundled directory purely
        # by whether it EXISTS in the source tree (confirmed against its
        # own configure script — no noconfigdirs/skipdirs gating on
        # --with-gmp/mpfr/mpc at all); those flags only redirect cc1's own
        # final LINK (gmplibs/gmpinc), so leaving the symlinks in place
        # would make gcc ALSO configure+build the bundled copies, wastefully
        # and — on this host==target scenario, whose $CC now carries
        # target_sysroot_cc's own explicit -L$INSTALL_DIR/$SYSTEM_KEY/usr/lib
        # (below) — brokenly: each bundled subdir's own throwaway libtool
        # (configured by gcc's build system itself, with no matching
        # --with-sysroot of its own) picks up that SAME -L and finds our
        # ALREADY-INSTALLED target .la files instead of its sibling bundled
        # ones, whose "=" sysroot-relative dependency_libs entries (see
        # mpfr.sh's own --with-sysroot comment) have nothing to substitute
        # against and degrade to a bare, wrong path. Every other caller
        # (pass1/pass1-native/pass2 in lib/tools.sh) never sets gmp/mpfr/mpc,
        # so this stays unconditional bundling there, unchanged.
        case $dependency in
            gmp)  [ -n "${gmp:-}" ]  && continue ;;
            mpfr) [ -n "${mpfr:-}" ] && continue ;;
            mpc)  [ -n "${mpc:-}" ]  && continue ;;
        esac
        sh $PROJECT_DIR/lfs fetch $dependency
        dependency_version=$(sh $PROJECT_DIR/lfs version $dependency)
        ln -sfnv \
           $SOURCE_DIR/$dependency-$dependency_version \
           $SOURCE_DIR/gcc-$package_version/$dependency
    done
}

# gmp/mpfr/mpc knobs (below, in prepare()): unset by every existing caller
# (pass1/pass1-native/pass2 in lib/tools.sh), so this gcc keeps building
# its own bundled copies symlinked in by fetch() above, exactly as before —
# a no-op there. A caller building a genuinely target-hosted gcc (host=
# $target, see package/native-toolchain.sh) instead points these at
# already-built target packages of gmp/mpfr/mpc (own cross-compiling
# ambiguity fixed at that level, see gmp.sh) — passing --with-gmp/--with-
# mpfr/--with-mpc makes gcc's own top-level configure skip configuring the
# symlinked-in bundled copies entirely (its own noconfigdirs mechanism) and
# link these prebuilt ones instead.

# target_sysroot_cc (host==target only — see lib/package.sh; a no-op for
# every existing caller, pass1/pass1-native/pass2 in lib/tools.sh, which
# all leave host unset): the native-toolchain.sh scenario above hands
# --with-gmp/--with-mpfr/--with-mpc an explicit, literal
# "-L$INSTALL_DIR/$SYSTEM_KEY/usr/lib" — and gcc's own TOP-LEVEL configure
# (before any Makefile exists, so --with-build-sysroot's effect on the
# generated build hasn't kicked in yet) immediately re-uses that same $CC
# to link a throwaway "gmp/mpfr version check" conftest against gmp/mpfr/
# mpc found via that literal -L. Found empirically on pi0 (this native gcc
# build's actual canary, mentioned but never hit by mpfr.sh/mpc.sh
# themselves, whose OWN target linking happens after their -L is already in
# place): the version-check link failed with "/usr/lib/libc.so.6: file
# format not recognized". Root cause is exactly target_sysroot_cc's own
# documented mechanism — plain $target-gcc's DEFAULT (compiled-in) sysroot
# is $TOOL_DIR/$target (the bootstrap per-target sysroot, see lib/tools.sh),
# not $INSTALL_DIR/$SYSTEM_KEY; ld happily resolves "-lc" through the
# explicit, non-sysroot-relative -L$INSTALL_DIR/$SYSTEM_KEY/usr/lib first,
# opens ITS libc.so (a linker script — glibc's own, containing a literal
# absolute "GROUP ( /usr/lib/libc.so.6 ... )" written at glibc's OWN
# build-time prefix=/usr), and since THIS SPECIFIC -L was not tagged
# sysroot-relative, ld does NOT re-relocate that inner absolute reference
# through the active sysroot — it opens literal "/usr/lib/libc.so.6" on
# this scratch container's own real root instead (bind-mounted from
# $TOOL_DIR/usr/lib, the BUILD host's native runtime — see docker-
# compose.yaml), which happens to be architecture-compatible on an aarch64
# build host cross-building for virt/pi4/pi5 (masking the bug there) but is
# a different, wrong architecture for pi0 (32-bit ARM), hence the hard
# failure. Calling target_sysroot_cc here (guarded, exactly like mpfr.sh/
# mpc.sh) points $CC's OWN --sysroot at $INSTALL_DIR/$SYSTEM_KEY instead —
# the very same tree --with-gmp/--with-mpfr/--with-mpc/--with-build-sysroot
# already target — so every implicit lookup (including this early
# version-check conftest, run long before --with-build-sysroot's own
# Makefile-level effect exists) resolves consistently against it too.
target_sysroot_cc

prepare() {
    # cross_target defaults to $target (the platform's real cross target —
    # every existing caller keeps working unchanged), but callers building
    # a build-host-native toolchain (used by build_tools()/Ch6 tools to
    # actually execute in the scratch container, as opposed to the
    # per-platform cross-compiler) explicitly pass cross_target="" to omit
    # --target/--host/--with-gxx-include-dir entirely. $target itself is
    # globally readonly and can't be reassigned even via a prefix
    # assignment, hence this separate var.
    : ${cross_target=$target}

    case $package_component in
        libstdc++)
            $package_source_dir/libstdc++-v3/configure \
                ${cross_target:+--host=$cross_target} \
                ${cross_target:+--target=$cross_target} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${multilib:+--enable-multilib=$multilib} \
                ${nls:+--enable-nls=$nls} \
                ${libstdcxx_pch:+--enable-libstdcxx-pch=$libstdcxx_pch} \
                ${cross_target:+--with-gxx-include-dir=/$cross_target/include/c++/$package_version}
            ;;
        *)
            # Reconcile the bundled gmp/mpfr/mpc symlinks with THIS build's
            # choice. fetch() above manages them, but fetch runs ONCE per
            # shared source extraction — whichever caller fetched first
            # imposes its choice on every later gcc build from the same
            # tree. Empirically, from a pristine state: the cross passes
            # (no gmp/mpfr/mpc vars) fetch first and symlink, so a later
            # native-toolchain gcc (vars set) still configured+built
            # in-tree mpc — whose toplevel-driven configure lacks mpc.sh's
            # own libtool --with-sysroot, so linking the target tree's
            # libmpfr.la chased its recorded /usr/lib/libgmp.la literally
            # into the container's real /usr/lib and failed ("libgmp.la is
            # not a valid libtool archive"; before pristine it resolved
            # only by accident, against whatever the TOOL_DIR mount had
            # accumulated there). prepare() is per-build (per-SYSTEM_KEY
            # work dir), the correct lifecycle step for a per-build
            # decision: external prebuilt copies (vars set) drop the
            # symlinks, bundled builds (vars unset) restore them.
            local dependency dependency_version wanted
            for dependency in mpfr gmp mpc; do
                case $dependency in
                    gmp)  wanted=${gmp:-} ;;
                    mpfr) wanted=${mpfr:-} ;;
                    mpc)  wanted=${mpc:-} ;;
                esac
                if [ -n "$wanted" ]; then
                    if [ -L $package_source_dir/$dependency ]; then
                        rm $package_source_dir/$dependency
                    fi
                elif [ ! -e $package_source_dir/$dependency ]; then
                    sh $PROJECT_DIR/lfs fetch $dependency
                    dependency_version=$(sh $PROJECT_DIR/lfs version $dependency)
                    ln -sfnv \
                       $SOURCE_DIR/$dependency-$dependency_version \
                       $package_source_dir/$dependency
                fi
            done

            # https://gcc.gnu.org/install/configure.html
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${cross_target:+--target=$cross_target} \
                ${arch:+--with-arch=$arch} \
                ${float:+--with-float=$float} \
                ${fpu:+--with-fpu=$fpu} \
                ${tune:+--with-tune=$tune} \
                ${abi:+--with-abi=$abi} \
                ${prefix:+--prefix=$prefix} \
                ${glibc_version:+--with-glibc-version=$glibc_version} \
                ${sysroot:+--with-sysroot=$sysroot} \
                ${build_sysroot:+--with-build-sysroot=$build_sysroot} \
                ${gmp:+--with-gmp=$gmp} \
                ${mpfr:+--with-mpfr=$mpfr} \
                ${mpc:+--with-mpc=$mpc} \
                ${newlib:+--with-newlib=$newlib} \
                ${headers:+--with-headers=$headers} \
                ${default_pie:+--enable-$default_pie} \
                ${default_ssp:+--enable-$default_ssp} \
                ${fixincludes:+--enable-fixincludes=$fixincludes} \
                ${nls:+--enable-nls=$nls} \
                ${shared:+--enable-shared=$shared} \
                ${multilib:+--enable-multilib=$multilib} \
                ${threads:+--enable-threads=$threads} \
                ${libatomic:+--enable-libatomic=$libatomic} \
                ${libgomp:+--enable-libgomp=$libgomp} \
                ${libquadmath:+--enable-libquadmath=$libquadmath} \
                ${libssp:+--enable-libssp=$libssp} \
                ${libvtv:+--enable-libvtv=$libvtv} \
                ${libstdcxx:+--enable-libstdcxx=$libstdcxx} \
                ${libsanitizer:+--enable-libsanitizer=$libsanitizer} \
                ${languages:+--enable-languages=$languages} \
                ${bootstrap:+--enable-bootstrap=$bootstrap}
            ;;
    esac
}

build() {
    make
}

install() {
    case $package_component in
        libstdc++)
            make install DESTDIR=$package_install_dir
            ;;
        *)
            make install DESTDIR=$package_install_dir
            case ${package_variant:-} in
                pass1)
                    cat $package_source_dir/gcc/limitx.h \
                        $package_source_dir/gcc/glimits.h \
                        $package_source_dir/gcc/limity.h \
                        > $($target-gcc -print-file-name=include)/limits.h
                    ;;
            esac

            # Native-for-target scenario (package/native-toolchain.sh: this
            # gcc's own host==target, i.e. it runs ON $target and emits
            # $target code — the guest-native toolchain). Reuse
            # target_sysroot_cc's own guard to identify it: every OTHER
            # caller (lib/tools.sh's pass1/pass1-native/pass2) leaves host
            # unset (a genuine cross build, build!=host), so this is false
            # for them and this whole block is a no-op there —
            # byte-identical tools/cross behavior.
            #
            # Both fixups belong here, in the package's own install step, so
            # they stage->archive->merge like everything else instead of
            # being patched by hand afterward in the merged tree.
            if [ "${host:-}" = "$target" ]; then
                # Bare "cc": this build already installs plain "gcc"/"g++"/
                # "c++" itself (hardlinked to the $target-prefixed names,
                # confirmed empirically — see native-toolchain.sh) but never
                # "cc", the POSIX-conventional name a plain ./configure or
                # Makefile run natively on the booted guest is liable
                # to look for first.
                ln -sfv gcc $package_install_dir/$prefix/bin/cc

                # usr/lib64 -> usr/lib: GCC hardcodes MULTILIB_OSDIRNAMES=
                # lib64 for aarch64 (and other 64-bit targets), so this
                # native-for-target gcc's own libstdc++.so*/libgcc_s.so* land
                # under usr/lib64 — off the search path of this project's
                # merged-usr, lib64-less target tree (glibc, and everything
                # else this project installs, only ever populates usr/lib).
                # Relocated HERE, in this package's own install step, rather
                # than by sed-ing gcc's shared source tree (which pass1/
                # pass1-native/pass2 also build from and whose existing,
                # unaffected-by-this-bug behavior must not change — e.g.
                # lib/tools.sh's own pass1-native copies FROM $native_target/
                # lib64 on purpose). The lib64->lib symlink keeps anything
                # still hardcoded to the lib64 path (this gcc's own
                # -print-file-name, recorded libtool .la libdirs) resolving.
                if [ -d $package_install_dir/$prefix/lib64 ]; then
                    mkdir -p $package_install_dir/$prefix/lib
                    cp -av $package_install_dir/$prefix/lib64/. $package_install_dir/$prefix/lib/
                    rm -rf $package_install_dir/$prefix/lib64
                    ln -sv lib $package_install_dir/$prefix/lib64
                fi
            fi
            ;;
    esac
}
