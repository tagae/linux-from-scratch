# Target System
# -------------
#
# Builds the system that runs on the platform into its own tree, $INSTALL_DIR/$SYSTEM_KEY, from
# which images are made, and which holds only what the running system needs.
#
# The cross toolchain that compiles the system has a sysroot of its own, which holds the same
# packages, plus what compiling against them needs: the kernel headers and the packages' dev
# components. The toolchain finds the platform's headers and libraries there, with no extra flags.
# Every platform goes through a cross toolchain, even one with the build machine's architecture.
#
# The kernel is configured from layers that every system gets, in package/linux/ (base, hardening,
# machine, architecture, userland), and from the optional fragments there that the system's features
# name on their `# Linux:` lines. A feature adds the packages listed in feature/<feature>.sh,
# installed the same way after the kernel.

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
    readonly system_dir=$INSTALL_DIR/$SYSTEM_KEY
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
    lfs_system_install tzdata

    # pkg-config sees the platform's libraries only, which the packages below install in the
    # sysroot. Their .pc files record /usr paths.
    export PKG_CONFIG_LIBDIR=$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig
    export PKG_CONFIG_SYSROOT_DIR=$sysroot
    export PKG_CONFIG_SYSTEM_INCLUDE_PATH=$sysroot/usr/include
    export PKG_CONFIG_SYSTEM_LIBRARY_PATH=$sysroot/usr/lib

    # Chapter 8: Installing Basic System Software
    ( manpages=no; lfs_system_install kmod )
    lfs_install_package kmod#dev
    ( bash_malloc=no; lfs_system_install bash )
    (
        # One program for all the utilities, which otherwise carry a copy of the same library each.
        single_binary=symlinks
        install_program=hostname
        lfs_system_install coreutils
    )
    lfs_system_install grep
    lfs_system_install sed
    lfs_system_install gawk
    (
        # Strong hashes for new passwords, and glibc's for checking older ones; nothing here needs
        # the interfaces of glibc's own libcrypt.
        hashes=strong,glibc obsolete_api=no
        lfs_system_install libxcrypt
        lfs_install_package libxcrypt#dev
    )
    (
        # Root, the only account, needs no setuid programs. Subordinate ids serve user namespaces,
        # which the kernels lack.
        suidperms=0755 subordinate_ids=no
        lfs_system_install shadow
    )
    (
        shared=yes normal=no debug=no ada=no cxx_binding=no stripping=no
        # The descriptions of the terminals these systems meet are built into the library, instead
        # of a database of every known terminal.
        fallbacks=dumb,linux,vt100,vt220,xterm,xterm-256color db_install=no
        pc_files=yes pkg_config_libdir=/usr/lib/pkgconfig
        lfs_system_install ncurses
        lfs_install_package ncurses#dev
    )
    # util-linux provides kill.
    ( kill=no; lfs_system_install procps-ng )
    (
        bindir=/usr/bin sbindir=/usr/sbin libdir=/usr/lib
        # What systemd runs (agetty, fsck, mount, sulogin, swapon), and the basic tools to manage
        # disks, logs and processes.
        all_programs=no
        libblkid=yes libuuid=yes libmount=yes libsmartcols=yes libfdisk=yes
        mount=yes fsck=yes agetty=yes sulogin=yes swapon=yes
        blkid=yes lsblk=yes fdisks=yes losetup=yes dmesg=yes kill=yes more=yes
        python=no systemd=no static=no
        makeinstall_chown=no makeinstall_setuid=no
        lfs_system_install util-linux
        lfs_install_package util-linux#dev
    )
    lfs_system_install systemd
    lfs_install_package systemd#dev

    # The readers of man and info pages. They come after the packages
    # above, which would otherwise pick up zlib, that mandoc requires, and configure differently.
    lfs_system_install zlib
    lfs_install_package zlib#dev
    lfs_system_install mandoc
    lfs_system_install texinfo

    # The kernel is archived under the fragments that configure it, so that systems with the same
    # ones share it, whatever their features.
    for fragment in $linux_fragments; do
        package_key=$package_key+$fragment
    done

    # Chapter 10: Making the LFS System Bootable
    ( fragments=$linux_fragments; lfs_system_install linux )
    # The Pi layout's FAT partition holds what the Raspberry Pi firmware boots from.
    if [ "${IMAGE_LAYOUT:-pi}" != single ]; then
        lfs_system_install firmware
        lfs_system_install boot
    fi

    # The Python packages of the features are for this version, which lib/category/python.sh reads.
    python_version=$(lfs_package_version python)
    for feature in $features; do
        package_key=$package_key+$feature
        ( . $feature_dir/$feature.sh )
    done

    # QEMU runs on the host, which cannot see the install tree (a Docker volume), but sees
    # WORK_DIR/boot.
    rm -rf $WORK_DIR/boot/$SYSTEM_KEY
    mkdir -pv $WORK_DIR/boot/$SYSTEM_KEY
    (
        cd $system_dir/boot
        cp -v kernel.img ${dev_tree_blob:+${dev_tree_blob##*/}} $WORK_DIR/boot/$SYSTEM_KEY/
    )
}

# Chapter 5: Compiling a Cross-Toolchain
#
# Builds the cross toolchain into TOOL_DIR. Its C library, which the final compiler links against,
# is the system's, installed into the system as well as the sysroot.
lfs_system_build_toolchain() {
    ( gprofng=no werror=no; lfs_install_tool binutils )
    (
        package_variant=pass1
        glibc_version=$(lfs_package_version glibc)
        default_pie=default-pie default_ssp=default-ssp
        # With a C++ compiler for the host that cannot link yet, glibc skips its C++ parts, instead
        # of using the build machine's.
        languages=c,c++
        newlib=yes headers=no
        shared=no threads=no
        libatomic=no libgomp=no libquadmath=no libssp=no libvtv=no libstdcxx=no libsanitizer=no
        lfs_install_tool gcc
    )
    lfs_install_package linux#headers
    (
        nscd=no enable_kernel=5.10
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
        libgomp=no libquadmath=no libssp=no libvtv=no libsanitizer=no
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
