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

        ( shared=yes gprofng=no werror=no; lfs_install_package binutils )

        (
            glibc_version=$(lfs_package_version glibc)
            languages=c,c++
            shared=yes threads=yes libstdcxx=yes
            fixincludes=no
            libatomic=no libgomp=no libquadmath=no libsanitizer=no libssp=no libvtv=no
            lfs_install_package gcc
        )
    )

    (
        export CC=$TOOL_DIR/usr/bin/gcc
        export CXX=$TOOL_DIR/usr/bin/g++

        # pkgconf's own compiled-in default search path is the literal /usr/lib/pkgconfig, and the
        # .pc files there record /usr paths that live under TOOL_DIR.
        export PKG_CONFIG_LIBDIR=$TOOL_DIR/usr/lib/pkgconfig PKG_CONFIG_SYSROOT_DIR=$TOOL_DIR

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
}

# Builds the remainder of the toolchain starting from the bootstrapped state.
lfs_tools_build() {
    mkdir -p ${TMPDIR:-/tmp}

    # glibc's own compiled-in default gconv module path is the literal /usr/lib/gconv
    export GCONV_PATH=$TOOL_DIR/usr/lib/gconv

    # pkgconf's own compiled-in default search path is the literal /usr/lib/pkgconfig, and the
    # .pc files there record /usr paths that live under TOOL_DIR.
    export PKG_CONFIG_LIBDIR=$TOOL_DIR/usr/lib/pkgconfig PKG_CONFIG_SYSROOT_DIR=$TOOL_DIR

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
    lfs_install_package perl
    ( manpages=no; lfs_install_package kmod )
    # The kernel's headers_install copies the headers with rsync.
    lfs_install_package rsync
    # The x86-64 kernel's objtool links libelf, from elfutils, whose sources come as .tar.bz2.
    lfs_install_package bzip2
    lfs_install_package elfutils
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
        mount=yes fdisks=yes losetup=yes fallocate=yes mountpoint=yes
        lfs_install_package util-linux
        lfs_install_package util-linux#dev
    )
    lfs_install_package btrfs-progs
    lfs_install_package dosfstools
    lfs_install_package libaio
    lfs_install_package lvm2#device-mapper
    lfs_install_package multipath-tools#kpartx
}

# Exports LDFLAGS so that native binaries carry a TOOL_DIR-relative interpreter/rpath
# pointing at the native glibc/libstdc++ under TOOL_DIR/usr.
lfs_tools_set_rtld_ldflags() {
    local rtld=$(find $TOOL_DIR/usr/lib -maxdepth 1 -name 'ld-linux-*.so.*' | head -1)
    [ -n "$rtld" ] || bail "Cannot find dynamic linker built by glibc"
    # A single rpath at $TOOL_DIR/usr/lib (= $(dirname $rtld)) is enough.
    export LDFLAGS="-Wl,--dynamic-linker=$rtld -Wl,-rpath,$(dirname $rtld)"
}
