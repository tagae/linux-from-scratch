# Build Toolchain
# ---------------
#
# This file contains all the utilities needed to build a build toolchain.
# The toolchain can then be used to build Linux systems for different platforms.
#
# The system on which the tools are being built is called the build system.
# The system on which the tools will run is called the host system.
# The system for which the resulting cross compiler generates code is called the target system.
#
# When build == host == target, we have a native toolchain.
# When build == host != target, we have a cross toolchain.
# When build != host == target, we have a cross-native toolchain.
# When build != host != target, we have a Canadian toolchain.

# See https://www.airs.com/ian/configure/configure_5.html

lfs_tools() {
    case "${1:-help}" in
        bootstrap) shift && lfs_tools_bootstrap ;;
        build) shift && lfs_tools_build ;;
        help)
            echo "Usage: $(basename "$0") tools <bootstrap|build>"
            if [ $# -eq 1 ]; then exit 0; else exit 1; fi ;;
        *) bail "Unknown command '$1'" ;;
    esac
}

# Builds the tools needed to run from scratch.
lfs_tools_bootstrap() {
    readonly nls=no
    readonly multilib=no
    readonly prefix=/usr

    readonly package_variant=bootstrap
    package_install_dir=$TOOL_DIR

    # Where the programs built from here on find their dynamic linker and libraries, whether
    # TOOL_DIR is mounted over /usr (the scratch container) or not (a Linux host).
    local rtld_dir=$TOOL_DIR/usr/lib

    lfs_install_package linux#headers
    (
        nscd=no enable_kernel=5.10 headers=$TOOL_DIR/usr/include
        lfs_install_package glibc
        lfs_install_package glibc#dev
    )

    lfs_tools_set_rtld_ldflags

    (
        readonly sysroot=$TOOL_DIR
        readonly build_sysroot=$TOOL_DIR

        # new_dtags: what the programs linked from here on find through their rpath (TOOL_DIR's
        # libraries) comes after LD_LIBRARY_PATH, which builds set to run what they just built
        # against the libraries they just built, rather than against those already in TOOL_DIR.
        (
            shared=yes gprofng=no werror=no new_dtags=yes
            lfs_install_package binutils
        )

        (
            glibc_version=$(lfs_package_version glibc)
            languages=c,c++
            shared=yes threads=yes libstdcxx=yes
            fixincludes=no
            libatomic=no libgomp=no libquadmath=no libsanitizer=no libssp=no libvtv=no
            # The compilers after the first stage ignore LDFLAGS.
            boot_ldflags="$LDFLAGS -static-libstdc++ -static-libgcc"
            # Rather than the build machine's, whatever comes first in PATH. Its linker would load
            # the LTO plugin built by the first stage, which needs a glibc as recent as TOOL_DIR's.
            ld=$TOOL_DIR/usr/bin/ld as=$TOOL_DIR/usr/bin/as
            lfs_install_package gcc
        )
    )

    (
        lfs_tools_set_env

        ( curses=no; lfs_install_package bash )
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

    mkdir -pv $BOOTSTRAP_DIR
    cp -v $TOOL_DIR/usr/bin/bash $BOOTSTRAP_DIR/bash
    cp -v $TOOL_DIR/usr/bin/env $BOOTSTRAP_DIR/env
}

# Builds the remainder of the toolchain starting from the bootstrapped state.
lfs_tools_build() {
    mkdir -p ${TMPDIR:-/tmp}

    lfs_tools_set_env

    # glibc's own compiled-in default gconv module path is the literal /usr/lib/gconv
    export GCONV_PATH=$TOOL_DIR/usr/lib/gconv

    readonly prefix=/usr
    readonly nls=no

    readonly package_variant=tools
    package_install_dir=$TOOL_DIR

    lfs_tools_set_rtld_ldflags

    lfs_install_package gettext
    lfs_install_package m4
    ( relocatable=yes; lfs_install_package bison )
    lfs_install_package patch
    lfs_install_package zlib
    lfs_install_package zlib#dev
    ( optimizations=no; lfs_install_package python )
    lfs_install_package gperf
    (
        python_version=$(lfs_package_version python)
        lfs_install_package markupsafe
        lfs_install_package jinja2
    )
    lfs_install_package flex
    lfs_install_package bc
    # Its compiled-in @INC is /usr/lib/perl5, and its scripts' shebang /usr/bin/perl: neither is
    # in TOOL_DIR.
    (
        sysroot=$TOOL_DIR shrplib=no relocatable=yes perlpath=$TOOL_DIR/usr/bin/perl
        lfs_install_package perl
    )
    ( manpages=no; lfs_install_package kmod )
    # The kernel's headers_install copies the headers with rsync.
    lfs_install_package rsync
    # The x86-64 kernel's objtool links libelf, from elfutils, whose sources come as .tar.bz2.
    lfs_install_package bzip2
    lfs_install_package elfutils
    # libcbor and libfido2 build with CMake.
    lfs_install_package cmake
    (
        shared=yes normal=no debug=no cxx_shared=yes
        lfs_install_package ncurses
        lfs_install_package ncurses#dev
    )
    (
        libdir=/usr/lib bindir=/usr/bin sbindir=/usr/sbin
        makeinstall_chown=no makeinstall_setuid=no
        all_programs=no
        libblkid=yes libuuid=yes libmount=yes libfdisk=yes libsmartcols=yes
        fdisks=yes
        lfs_install_package util-linux
        lfs_install_package util-linux#dev
    )
    lfs_install_package btrfs-progs
    lfs_install_package dosfstools
    lfs_install_package mtools
}

# Installs a package that runs on the build machine into TOOL_DIR, built as the tools are, from
# another phase, such as the system's.
lfs_tools_install() (
    unset host
    package_variant=tools
    package_install_dir=$TOOL_DIR
    lfs_tools_set_env
    lfs_tools_set_rtld_ldflags
    lfs_install_package $1
)

# Sets the environment that the tools are built in.
#
# They are built with the compiler that bootstrap staged, not with whatever `gcc` comes first in
# PATH. The scratch container mounts TOOL_DIR over /usr, but on a Linux host /usr holds the host's
# own toolchain, whose linker resolves the absolute /usr/lib paths in TOOL_DIR's linker scripts
# (libc.so) against the host's libc. The bootstrapped gcc has TOOL_DIR as its sysroot, and runs its
# own as and ld.
lfs_tools_set_env() {
    export CC=$TOOL_DIR/usr/bin/gcc CXX=$TOOL_DIR/usr/bin/g++

    # pkgconf's own compiled-in default search path is the literal /usr/lib/pkgconfig, and the
    # .pc files there record /usr paths that live under TOOL_DIR. The system phase points the
    # system search paths at its sysroot.
    export PKG_CONFIG_LIBDIR=$TOOL_DIR/usr/lib/pkgconfig PKG_CONFIG_SYSROOT_DIR=$TOOL_DIR
    unset PKG_CONFIG_SYSTEM_INCLUDE_PATH PKG_CONFIG_SYSTEM_LIBRARY_PATH
}

# Exports LDFLAGS so that native binaries carry a TOOL_DIR-relative interpreter/rpath
# pointing at the native glibc/libstdc++ under TOOL_DIR/usr.
lfs_tools_set_rtld_ldflags() {
    local rtld=$(find $TOOL_DIR/usr/lib -maxdepth 1 -name 'ld-linux-*.so.*' | head -1)
    [ -n "$rtld" ] || bail "Cannot find dynamic linker built by glibc"
    # A single rpath at $TOOL_DIR/usr/lib (= $(dirname $rtld)) is enough.
    export LDFLAGS="-Wl,--dynamic-linker=$rtld -Wl,-rpath,$(dirname $rtld)"
}
