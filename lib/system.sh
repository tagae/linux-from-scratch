# Target System
# -------------
#
# Builds the system that a profile lists into its own tree, $INSTALL_DIR/$PROFILE, from which
# images are made, and which holds only what the running system needs.
#
# The cross toolchain that compiles the system has a sysroot of its own, which holds the same
# packages, plus what compiling against them needs: the kernel headers and the packages' dev
# components. The toolchain finds the platform's headers and libraries there, with no extra flags.
# Every platform goes through a cross toolchain, even one with the build machine's architecture.
#
# Besides the tree's layout (system-files) and the toolchain's C library and runtime, everything in
# the system comes from its profile, profile/<profile>.sh: the whole list of packages, in the order
# they are installed, with the options of each at its call site. The init system and the kernel are
# among them. The kernel is configured from layers that every system gets, in package/linux/ (base,
# platform, architecture), and from the capabilities there that the profile names in the
# `capabilities` option of the linux package.

lfs_system() {
    case "${1:-help}" in
        build) shift && lfs_system_build ;;
        help)
            echo "Usage: $(basename "$0") system <build>"
            if [ $# -eq 1 ]; then exit 0; else exit 1; fi ;;
        *) bail "Unknown command '$1'" ;;
    esac
}

lfs_system_build() {
    mkdir -p ${TMPDIR:-/tmp}

    readonly nls=no
    readonly multilib=no
    readonly prefix=/usr
    readonly system_dir=$INSTALL_DIR/$PROFILE
    # Under the key the cross toolchain is archived under, as the toolchain records the path.
    readonly sysroot=$WORK_DIR/$package_key/sysroot

    # With an explicit build triplet, autoconf never mistakes a platform of the build machine's
    # architecture for the build machine itself, and never runs what it compiles.
    readonly build=$(gcc -dumpmachine)
    host=$target_triplet

    # The trees hold exactly what the packages below install, with the permissions they were
    # packaged with (setuid and sticky bits included), which tar drops for unprivileged users.
    rm -rf $system_dir $sysroot
    lfs_sbom_start
    package_install_dir=$sysroot
    export TAR_OPTIONS=--same-permissions

    # Programs and libraries carry no debugging information, and are stripped at link time, through
    # -Wl so that libtool passes it on to shared libraries too. Autoconf and meson both take these
    # flags for the platform's code; the kernel does not read them.
    export CFLAGS=-O2 CXXFLAGS=-O2 LDFLAGS=-Wl,-s

    # Merged-usr layout, which every later package installs through.
    lfs_system_install system-files

    lfs_system_build_toolchain
    lfs_system_install gcc#runtime

    # pkg-config sees the platform's libraries only, which the profile installs in the sysroot.
    # Their .pc files record /usr paths.
    export PKG_CONFIG_LIBDIR=$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig
    export PKG_CONFIG_SYSROOT_DIR=$sysroot
    export PKG_CONFIG_SYSTEM_INCLUDE_PATH=$sysroot/usr/include
    export PKG_CONFIG_SYSTEM_LIBRARY_PATH=$sysroot/usr/lib

    # The Python packages of the profile are for this version, which lib/python.sh reads.
    python_version=$(lfs_package_version python)

    ( . $profile_dir/$PROFILE.sh )

    # QEMU runs on the host, which cannot see the install tree (a Docker volume), but sees
    # WORK_DIR/boot: the kernel that the profile installed, and the platform's device tree.
    rm -rf $WORK_DIR/boot/$PROFILE
    mkdir -pv $WORK_DIR/boot/$PROFILE
    (
        cd $system_dir/boot
        cp -v kernel.img ${dev_tree_blob:+${dev_tree_blob##*/}} $WORK_DIR/boot/$PROFILE/
    )
}

# Chapter 5: Compiling a Cross-Toolchain
#
# Builds the cross toolchain into TOOL_DIR. Its C library, which the final compiler links against,
# is the system's, installed into the system as well as the sysroot.
lfs_system_build_toolchain() {
    lfs_install_tool binutils
    (
        package_variant=pass1
        glibc_version=$(lfs_package_version glibc)
        default_pie=default-pie default_ssp=default-ssp
        # With a C++ compiler for the host that cannot link yet, glibc skips its C++ parts, instead
        # of using the build machine's.
        languages=c,c++
        newlib=yes headers=no
        shared=no threads=no
        libstdcxx=no
        lfs_install_tool gcc
    )
    lfs_install_package linux#headers
    (
        enable_kernel=5.10
        # The time zone data is tzdata's, compiled by its own zic.
        timezone_tools=no
        lfs_system_install glibc
        lfs_install_package glibc#dev
    )
    (
        glibc_version=$(lfs_package_version glibc)
        languages=c,c++
        shared=yes threads=posix
        default_pie=default-pie default_ssp=default-ssp
        # Shipped with the runtime, for the programs that need atomic operations the CPU lacks.
        libatomic=yes
        lfs_install_tool gcc
    )
}

# Installs a package into the system, and into the sysroot for the packages compiled after it. The
# system's SBOM lists the packages that it holds.
lfs_system_install() {
    lfs_install_package $1
    ( package_install_dir=$system_dir; lfs_unarchive_package $1 )
    lfs_sbom_record_package $1
}

# Installs a package of the cross toolchain, which runs on the build machine and compiles for the
# platform, tuned for its CPU.
lfs_install_tool() (
    unset host
    target=$target_triplet
    arch=${target_gcc_arch:-} tune=${target_gcc_tune:-} abi=${target_gcc_abi:-}
    fpu=${target_gcc_fpu:-} float=${target_gcc_float:-}

    : ${package_variant:=cross}
    package_install_dir=$TOOL_DIR

    # The platform's code in the toolchain (libgcc, libstdc++) is built like the system's.
    export CFLAGS_FOR_TARGET=$CFLAGS CXXFLAGS_FOR_TARGET=$CXXFLAGS LDFLAGS_FOR_TARGET=${LDFLAGS:-}
    lfs_tools_set_rtld_ldflags
    lfs_install_package $1
)
