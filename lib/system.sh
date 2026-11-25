# Target System
# -------------
#
# Builds the system's root tree, the system tree, into $system_dir.
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
#
# What gives a system its own look and accounts belongs to the profile, not to a package: the files
# in profile/<profile>/files/ (issue, motd, the shell profile), which the build copies once the packages
# are in, and the accounts that the profile adds (lfs_system_set_root, lfs_system_add_user).

lfs_system_build() {
    mkdir -p ${TMPDIR:-/tmp}

    readonly nls=no
    readonly multilib=no
    readonly prefix=/usr
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

    # The documentation is indexed in the profile's shell, whose man and info say what the system
    # ships, once every page is in.
    (
        . $profile_dir/$LFS_PROFILE.sh
        lfs_system_add_profile_files
        lfs_system_index_documentation
    )

    # QEMU runs on the host, which cannot see the system tree (in a Docker volume), but sees
    # LFS_WORK_DIR/boot: the kernel that the profile installed, the platform's device tree, and the
    # kernel command line of a system that has one (the boot package's).
    rm -rf $LFS_WORK_DIR/boot/$LFS_PROFILE
    mkdir -pv $LFS_WORK_DIR/boot/$LFS_PROFILE
    (
        cd $system_dir/boot
        cp -v kernel.img ${dev_tree_blob:+${dev_tree_blob##*/}} $LFS_WORK_DIR/boot/$LFS_PROFILE/
        [ ! -e cmdline.txt ] || cp -v cmdline.txt $LFS_WORK_DIR/boot/$LFS_PROFILE/
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

# Copies the files of the profile, profile/<profile>/files/, into the system once its packages are in:
# the path of a file under that directory is its path in the system (profile/virt/files/etc/issue is
# /etc/issue). Next to it, test/ has the profile's tests, which stay out of the system. A file is 0755
# if the checkout has it executable, else 0644. The profile's files
# belong to it alone: a path that a package installed is an error. The files are in no archive and
# no SBOM, as the build copies them each time. The name of the regular account, LFS_USER, is the
# only variable that envsubst replaces in them, in their paths as in their contents: a file names it
# as `$LFS_USER`, and a file of the account's home directory is under home/$LFS_USER/.
lfs_system_add_profile_files() (
    local dir=$profile_dir/$LFS_PROFILE/files file dest
    [ -d $dir ] || return 0
    cd $dir
    for file in $(find . -type f | sed 's|^\./||' | sort); do
        dest=$(printf '%s' "$file" | envsubst '$LFS_USER')
        ! [ -e $system_dir/$dest ] && ! [ -L $system_dir/$dest ] \
            || bail "profile/$LFS_PROFILE/files/$file is a file of a package, not of the profile"
        mkdir -p $system_dir/$(dirname $dest)
        envsubst '$LFS_USER' < $file > $system_dir/$dest
        if [ -x $file ]; then chmod 0755 $system_dir/$dest; else chmod 0644 $system_dir/$dest; fi
    done
)

# Indexes the manual pages, which man, whatis and apropos search, and makes the directory of the
# Info pages, which info starts from, in a system that ships them (man=yes, info=yes), with mandoc and
# texinfo built for the build machine, as the system's cannot run on it. An Info page that has no
# entry for the directory is left out of it.
lfs_system_index_documentation() {
    if [ "${man:-no}" = yes ]; then
        lfs_tools_install mandoc
        makewhatis $system_dir/usr/share/man
    fi
    if [ "${info:-no}" = yes ]; then
        lfs_tools_install texinfo
        local file
        for file in $system_dir/usr/share/info/*.info; do
            install-info --dir-file=$system_dir/usr/share/info/dir $file || :
        done
    fi
}

# Runs an account tool of the build machine (useradd, usermod, chpasswd) on the system tree. The tools
# stamp the day of a password change, which is pinned to day 19000, so that the same build makes the
# same files whatever the day. They leave the previous version of the files next to them.
_system_account() {
    local tool=$1
    shift
    SOURCE_DATE_EPOCH=$((19000 * 86400)) $tool --prefix $system_dir "$@"
    rm -f $system_dir/etc/passwd- $system_dir/etc/shadow-
}

# Sets the password of an account of the system: hashed with SHA-512, which the C library of every
# system checks, whatever it hashes with for new passwords. No password is an empty hash, which the
# login on the console takes as an account that asks for nothing. The systems have no remote login,
# so the console is the way in, and whoever reaches it has the machine.
_system_set_password() {
    if [ -n "$2" ]; then
        printf '%s:%s\n' "$1" "$2" | _system_account chpasswd --crypt-method SHA512
    else
        _system_account usermod --password '' -- "$1"
    fi
}

# Sets root's account: no password, unless LFS_ROOT_PASSWORD asks for one, and `root_shell` for
# shell (/bin/sh unless set), and gives root its home directory, /root. The init ships root locked,
# so a profile that does not call this has no way to log in. The account belongs to the build, not
# to a package: it is in no archive.
lfs_system_set_root() (
    local shell=${root_shell:-/bin/sh}
    [ -x $system_dir$shell ] || bail "root_shell '$shell' is not in the system"
    _system_account usermod --shell $shell -- root
    _system_set_password root "${LFS_ROOT_PASSWORD:-}"
    mkdir -pv -m 0700 $system_dir/root
)

# Adds a regular account to the system: LFS_USER, with no password unless LFS_PASSWORD sets one,
# UID 1000, the group `users`, `user_shell` for shell (/bin/sh unless set), and a home directory
# that lib/image.sh gives to it. The account belongs to the build, not to a package: it is in no
# archive.
lfs_system_add_user() (
    local name=${LFS_USER:-}
    [ -n "$name" ] || bail "LFS_USER, the name of the regular account, is not set"
    # The name that utmp, which the console's login records, can hold; useradd checks the rest.
    [ ${#name} -le 32 ] || bail "LFS_USER '$name' is longer than 32 characters"
    _system_account useradd --uid 1000 --gid users --home-dir "/home/$name" --no-create-home \
        --no-log-init --shell ${user_shell:-/bin/sh} -- "$name"
    _system_set_password "$name" "${LFS_PASSWORD:-}"
    mkdir -pv $system_dir/home
    mkdir -v -m 0700 "$system_dir/home/$name"
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
