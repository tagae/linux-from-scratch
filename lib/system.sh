# Target System
# -------------
#
# Builds the system's root tree into $LFS_INSTALL_DIR/$LFS_PROFILE.
#
# The cross toolchain that compiles the system has a sysroot of its own, which holds the same
# packages, plus their dev components. The toolchain finds the platform's headers and libraries
# there, with no extra flags.  Every platform goes through a cross toolchain, even one with the
# build machine's architecture.
#
# Besides the tree's layout (system-files), everything in the system comes from its profile,
# profile/<profile>.sh: the whole list of packages, in the order they are installed, with the options
# of each at its call site. It starts with the cross toolchain (lfs_system_toolchain), which names
# the system's C library. The init system and the kernel are among the packages. The kernel is
# configured from layers that every system gets, in package/linux/ (base, platform, architecture),
# and from the capabilities there that the profile names in the `capabilities` option of the linux
# package.

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
    readonly system_dir=$LFS_INSTALL_DIR/$LFS_PROFILE
    # Under the key the cross toolchain is archived under, as the toolchain records the path.
    readonly sysroot=$LFS_WORK_DIR/$package_key/sysroot

    # With an explicit build triplet, autoconf never mistakes a platform of the build machine's
    # architecture for the build machine itself, and never runs what it compiles.
    readonly build=$(gcc -dumpmachine)

    # The trees hold exactly what the packages below install, with the permissions they were
    # packaged with (setuid and sticky bits included), which tar drops for unprivileged users.
    rm -rf $system_dir $sysroot
    lfs_sbom_start
    package_install_dir=$sysroot
    export TAR_OPTIONS=--same-permissions

    # Programs and libraries carry no debugging information, and are stripped at link time, through
    # -Wl so that libtool passes it on to shared libraries too. Their segments align to the 4 KiB
    # pages of the kernels: the linker of aarch64 aligns them to 64 KiB, and pads the files to it
    # (up to 64 KiB in each). Autoconf and meson both take these flags for the platform's code; the
    # kernel does not read them.
    export CFLAGS=-O2 CXXFLAGS=-O2 LDFLAGS="-Wl,-s -Wl,-z,max-page-size=4096"

    # Merged-usr layout, which every later package installs through.
    lfs_system_install system-files

    # The Python packages of the profile are for this version, which lib/python.sh reads.
    python_version=$(lfs_package_version python)

    ( . $profile_dir/$LFS_PROFILE.sh )

    # QEMU runs on the host, which cannot see the install tree (a Docker volume), but sees
    # LFS_WORK_DIR/boot: the kernel that the profile installed, and the platform's device tree.
    rm -rf $LFS_WORK_DIR/boot/$LFS_PROFILE
    mkdir -pv $LFS_WORK_DIR/boot/$LFS_PROFILE
    (
        cd $system_dir/boot
        cp -v kernel.img ${dev_tree_blob:+${dev_tree_blob##*/}} $LFS_WORK_DIR/boot/$LFS_PROFILE/
    )
}

# Chapter 5: Compiling a Cross-Toolchain
#
# The first statement of a profile, which gives the C library of the system, `glibc` or `musl`: the
# library names the ABI of the target triplet. Builds the cross toolchain into LFS_TOOL_DIR. Its C
# library, which the final compiler links against, is the system's, installed into the system as
# well as the sysroot.
lfs_system_toolchain() {
    local libc=$1 glibc_version=
    case $libc in
        glibc) target_abi=gnu glibc_version=$(lfs_package_version glibc) ;;
        musl) target_abi=musl ;;
        *) bail "Unknown C library '$libc': must be glibc or musl" ;;
    esac

    # The platform may have an EABI (eabihf), which follows the library's name in the ABI.
    readonly target_abi=$target_abi${target_eabi:-}
    readonly target_triplet=$target_arch-$target_vendor-$target_kernel-$target_abi
    host=$target_triplet

    lfs_toolchain_install binutils
    (
        package_variant=pass1
        default_pie=default-pie default_ssp=default-ssp
        # With a C++ compiler for the host that cannot link yet, glibc skips its C++ parts, instead
        # of using the build machine's.
        languages=c,c++
        newlib=yes headers=no
        shared=no threads=no
        libstdcxx=no
        lfs_toolchain_install gcc
    )
    lfs_sysroot_install linux#headers
    case $libc in
        glibc)
            (
                enable_kernel=5.10
                # The time zone data is tzdata's, compiled by its own zic.
                timezone_tools=no
                lfs_system_install glibc
                lfs_sysroot_install glibc#dev
            )
            ;;
        musl)
            lfs_system_install musl
            lfs_sysroot_install musl#dev
            ;;
    esac
    (
        languages=c,c++
        shared=yes threads=posix
        default_pie=default-pie default_ssp=default-ssp
        # Built for the runtime, for the programs that need atomic operations the CPU lacks.
        libatomic=yes
        lfs_toolchain_install gcc
    )

    # From here on, pkg-config sees the platform's libraries only, which the profile installs in the
    # sysroot. Their .pc files record /usr paths.
    export PKG_CONFIG_LIBDIR=$sysroot/usr/lib/pkgconfig:$sysroot/usr/share/pkgconfig
    export PKG_CONFIG_SYSROOT_DIR=$sysroot
    export PKG_CONFIG_SYSTEM_INCLUDE_PATH=$sysroot/usr/include
    export PKG_CONFIG_SYSTEM_LIBRARY_PATH=$sysroot/usr/lib
}

# Installs a package into the sysroot only: the packages that come after it are compiled against what
# the sysroot holds, such as the headers and libraries of a `dev` component, which the system itself
# does not need.
lfs_sysroot_install() (
    package_install_dir=$sysroot
    lfs_install_package $1
)

# Installs a package into the system, and into the sysroot for the packages compiled after it. The
# system's SBOM lists the packages that it holds.
lfs_system_install() {
    lfs_sysroot_install $1
    ( package_install_dir=$system_dir; lfs_unarchive_package $1 )
    lfs_sbom_record_package $1
}

# Adds a regular account to the system: LFS_USER, with LFS_PASSWORD (its name, unless set) for
# password, UID 1000, the group `users`, `user_shell` for shell (/bin/sh unless set), and a home
# directory that lib/image.sh gives to it. The account belongs to the build, not to a package: it is
# in no archive. The password is hashed with SHA-512, which libxcrypt checks whatever it hashes with
# for new passwords.
lfs_system_add_user() (
    local name=${LFS_USER:-} password hash
    [ -n "$name" ] || bail "LFS_USER, the name of the regular account, is not set"
    case $name in
        [!a-z_]*|*[!a-z0-9_-]*) bail "LFS_USER '$name' is not a valid account name" ;;
    esac
    [ ${#name} -le 32 ] || bail "LFS_USER '$name' is longer than 32 characters"
    ! grep -q "^$name:" $system_dir/etc/passwd || bail "LFS_USER '$name' is an account of the system"
    password=${LFS_PASSWORD:-$name}
    hash=$(printf '%s\n' "$password" | openssl passwd -6 -stdin)
    echo "$name:x:1000:999:$name:/home/$name:${user_shell:-/bin/sh}" >> $system_dir/etc/passwd
    echo "$name:$hash:19000:0:99999:7:::" >> $system_dir/etc/shadow
    mkdir -pv $system_dir/home
    mkdir -v -m 0700 $system_dir/home/$name
)

# Installs a package of the cross toolchain, which runs on the build machine and compiles for the
# platform, tuned for its CPU.
lfs_toolchain_install() (
    unset host
    man=no info=no
    target=$target_triplet
    arch=${target_gcc_arch:-} tune=${target_gcc_tune:-} abi=${target_gcc_abi:-}
    fpu=${target_gcc_fpu:-} float=${target_gcc_float:-}

    : ${package_variant:=cross}
    package_install_dir=$LFS_TOOL_DIR

    # The platform's code in the toolchain (libgcc, libstdc++) is built like the system's.
    export CFLAGS_FOR_TARGET=$CFLAGS CXXFLAGS_FOR_TARGET=$CXXFLAGS LDFLAGS_FOR_TARGET=${LDFLAGS:-}
    lfs_tools_set_rtld_ldflags
    lfs_install_package $1
)
