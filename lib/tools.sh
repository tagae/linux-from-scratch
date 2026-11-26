# Build Toolchain
# ---------------
#
# Builds the tools of the build machine, with which the systems of every platform are built.
#
# The build system builds a program, the host system runs it, and the target system is the one a
# cross compiler generates code for (https://www.airs.com/ian/configure/configure_5.html).

# The tools run on the build machine whatever the platform, so they are built once under a key of
# their own. The cross toolchain of a platform, which runs on the build machine too, is built
# together with the system, and is also installed in LFS_TOOL_DIR.
readonly tools_key=tools

# Builds the tools needed to build a toolchain from scratch.
lfs_tools_bootstrap() {
    # Bison bakes the m4 path its configure found. Wherever a real /usr/bin/m4 exists, prefer it.
    if [ -x /usr/bin/m4 ]; then
        : ${M4:=/usr/bin/m4}
        export M4
        readonly M4
    fi

    readonly nls=no
    readonly multilib=no
    readonly prefix=/usr

    # The tools are the same for every system, whatever documentation it has.
    man=no info=no

    readonly package_variant=bootstrap
    package_install_dir=$LFS_TOOL_DIR
    package_key=$tools_key

    # Where the programs built from here on find their dynamic linker and libraries, whether
    # LFS_TOOL_DIR is mounted over /usr (the scratch container) or not (a Linux host).
    local rtld_dir=$LFS_TOOL_DIR/usr/lib

    lfs_install_package linux#headers
    (
        enable_kernel=5.10 headers=$LFS_TOOL_DIR/usr/include
        lfs_install_package glibc
        lfs_install_package glibc#dev
    )

    lfs_tools_set_rtld_ldflags

    (
        readonly sysroot=$LFS_TOOL_DIR
        readonly build_sysroot=$LFS_TOOL_DIR

        # new_dtags: what the programs linked from here on find through their rpath (LFS_TOOL_DIR's
        # libraries) comes after LD_LIBRARY_PATH, which builds set to run what they just built
        # against the libraries they just built, rather than against those already in LFS_TOOL_DIR.
        (
            shared=yes new_dtags=yes
            lfs_install_package binutils
        )

        (
            glibc_version=$(lfs_package_version glibc)
            languages=c,c++
            shared=yes threads=yes libstdcxx=yes
            fixincludes=no
            # The compilers after the first stage ignore LDFLAGS.
            boot_ldflags="$LDFLAGS -static-libstdc++ -static-libgcc"
            # Rather than the build machine's, whatever comes first in PATH. Its linker would load
            # the LTO plugin built by the first stage, which needs a glibc as recent as
            # LFS_TOOL_DIR's.
            ld=$LFS_TOOL_DIR/usr/bin/ld as=$LFS_TOOL_DIR/usr/bin/as
            lfs_install_package gcc
        )
    )

    (
        lfs_tools_set_env

        ( sh_link=yes; lfs_install_package bash )
        lfs_install_package coreutils
        lfs_install_package findutils
        lfs_install_package sed
        lfs_install_package gawk
        lfs_install_package grep
        lfs_install_package make
        lfs_install_package diffutils
        lfs_install_package gzip
        lfs_install_package tar
        lfs_install_package xz
        lfs_install_package pkgconf
        lfs_install_package openssl
        lfs_install_package wget
        lfs_install_package meson
        lfs_install_package ninja
        lfs_install_package libtasn1
        lfs_install_package p11-kit
        lfs_install_package make-ca
        lfs_install_package ca-certificates
    )

    # Artefacts produced by bootstrap, needed to build a system from scratch.
    local bootstrap_dir=$LFS_WORK_DIR/bootstrap
    mkdir -pv $bootstrap_dir
    cp -v $LFS_TOOL_DIR/usr/bin/bash $bootstrap_dir/bash
    cp -v $LFS_TOOL_DIR/usr/bin/env $bootstrap_dir/env
}

# Builds the remainder of the toolchain starting from the bootstrapped state.
lfs_tools_build() {
    mkdir -p ${TMPDIR:-/tmp}

    lfs_tools_set_env

    # glibc's own compiled-in default gconv module path is the literal /usr/lib/gconv.
    export GCONV_PATH=$LFS_TOOL_DIR/usr/lib/gconv

    readonly prefix=/usr
    readonly nls=no

    man=no info=no

    readonly package_variant=tools
    package_install_dir=$LFS_TOOL_DIR
    package_key=$tools_key

    lfs_tools_set_rtld_ldflags

    lfs_install_package gettext
    lfs_install_package m4
    ( relocatable=yes; lfs_install_package bison )
    lfs_install_package patch
    lfs_install_package zlib
    lfs_install_package zlib#dev
    # With pip, which builds the Python packages.
    ( ensurepip=upgrade; lfs_install_package python )
    lfs_install_package gperf
    (
        python_version=$(lfs_package_version python)
        lfs_install_package python/markupsafe
        lfs_install_package python/jinja2
    )
    lfs_install_package flex
    lfs_install_package bc
    # Its compiled-in @INC is /usr/lib/perl5, and its scripts' shebang /usr/bin/perl: neither is
    # in LFS_TOOL_DIR.
    (
        sysroot=$LFS_TOOL_DIR shrplib=no relocatable=yes perlpath=$LFS_TOOL_DIR/usr/bin/perl
        lfs_install_package perl
    )
    lfs_install_package kmod
    # The kernel's headers_install copies the headers with rsync.
    lfs_install_package rsync
    # The x86-64 kernel's objtool links libelf, from elfutils, whose sources come as .tar.bz2.
    lfs_install_package bzip2
    lfs_install_package elfutils
    # libcbor and libfido2 build with CMake.
    lfs_install_package cmake
    (
        shared=yes cxx_binding=yes cxx_shared=yes db_install=yes
        lfs_install_package ncurses
        lfs_install_package ncurses#dev
    )
    (
        libdir=/usr/lib bindir=/usr/bin sbindir=/usr/sbin
        libblkid=yes libuuid=yes libmount=yes libfdisk=yes libsmartcols=yes
        fdisks=yes
        lfs_install_package util-linux
        lfs_install_package util-linux#dev
    )
    lfs_install_package btrfs-progs
    lfs_install_package dosfstools
    lfs_install_package mtools
    # useradd, usermod and chpasswd write the accounts of a system tree (lib/system.sh), and hash
    # its passwords with libxcrypt.
    lfs_install_package libxcrypt
    lfs_install_package libxcrypt#dev
    lfs_install_package shadow
}

# Installs a package that runs on the build machine into LFS_TOOL_DIR, built as the tools are, from
# another phase, such as the system's.
lfs_tools_install() (
    unset host
    man=no info=no
    package_variant=tools
    package_install_dir=$LFS_TOOL_DIR
    lfs_tools_set_env
    lfs_tools_set_rtld_ldflags
    lfs_install_package $1
)

# Sets the environment that the tools are built in.
#
# They are built with the compiler that bootstrap staged, not with whatever `gcc` comes first in
# PATH. The scratch container mounts LFS_TOOL_DIR over /usr, but on a Linux host /usr holds the
# host's own toolchain, whose linker resolves the absolute /usr/lib paths in LFS_TOOL_DIR's linker
# scripts (libc.so) against the host's libc. The bootstrapped gcc has LFS_TOOL_DIR as its sysroot,
# and runs its own as and ld.
lfs_tools_set_env() {
    export CC=$LFS_TOOL_DIR/usr/bin/gcc CXX=$LFS_TOOL_DIR/usr/bin/g++

    # pkgconf's own compiled-in default search path is the literal /usr/lib/pkgconfig, and the
    # .pc files there record /usr paths that live under LFS_TOOL_DIR. The system phase points the
    # system search paths at its sysroot.
    export PKG_CONFIG_LIBDIR=$LFS_TOOL_DIR/usr/lib/pkgconfig PKG_CONFIG_SYSROOT_DIR=$LFS_TOOL_DIR
    unset PKG_CONFIG_SYSTEM_INCLUDE_PATH PKG_CONFIG_SYSTEM_LIBRARY_PATH
}

# Exports the LDFLAGS that give the programs built for the build machine the dynamic linker and the
# libraries (glibc, libstdc++) of LFS_TOOL_DIR/usr/lib, where both are.
lfs_tools_set_rtld_ldflags() {
    local rtld=$(find $LFS_TOOL_DIR/usr/lib -maxdepth 1 -name 'ld-linux-*.so.*' | head -1)
    [ -n "$rtld" ] || bail "Cannot find dynamic linker built by glibc"
    export LDFLAGS="-Wl,--dynamic-linker=$rtld -Wl,-rpath,$(dirname $rtld)"
}
