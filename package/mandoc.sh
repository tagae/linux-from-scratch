: ${package_version:=1.14.6}
: ${package_source:=https://mandoc.bsd.lv/snapshots/mandoc-$package_version.tar.gz}
: ${package_source_hash:=sha256:8bf0d570f01e70a6e124884088870cbed7537f36328d512909eb10cd53179d9c}
: ${package_description:=Manual page compiler and viewer (man, apropos, whatis).}
: ${package_license:=ISC AND BSD-2-Clause AND BSD-3-Clause}

# mandoc builds in its source tree, with a configure script that runs the test programs it compiles,
# which cannot work for another architecture than the build machine's. It takes every result as
# given in configure.local instead, here those of glibc: what the tests find, apart from glibc's
# lack of BSD-only functions (their compatibility versions are built), is what the platform has.
prepare() {
    case $package_component in
        mandoc)
            cp -Rp $package_source_dir/. .
            cat > configure.local <<EOF
CC=${host:+$host-}gcc
AR=${host:+$host-}ar
CFLAGS="${CFLAGS:-}"
LDFLAGS="${LDFLAGS:-}"
PREFIX=$prefix
MANDIR=$prefix/share/man
MANPATH_DEFAULT=$prefix/share/man
MANPATH_BASE=$prefix/share/man
OSENUM=MANDOC_OS_OTHER
BINM_PAGER=more

# Dynamic linking, and no wide characters: only the C locale exists.
HAVE_STATIC=0
HAVE_WCHAR=0
HAVE_WFLAG=0
HAVE_LESS_T=0
NEED_GNU_SOURCE=1

HAVE_ATTRIBUTE=1
HAVE_CMSG=1
HAVE_DIRENT_NAMLEN=0
HAVE_EFTYPE=0
HAVE_ENDIAN=1
HAVE_ERR=1
HAVE_FTS=1
HAVE_GETLINE=1
HAVE_GETSUBOPT=1
HAVE_ISBLANK=1
HAVE_MKDTEMP=1
HAVE_MKSTEMPS=1
HAVE_NANOSLEEP=1
HAVE_NTOHL=1
HAVE_O_DIRECTORY=1
HAVE_OHASH=0
HAVE_PATH_MAX=1
HAVE_PLEDGE=0
HAVE_PROGNAME=0
HAVE_REALLOCARRAY=1
HAVE_RECALLOCARRAY=0
HAVE_RECVMSG=1
HAVE_REWB_BSD=0
HAVE_REWB_SYSV=1
HAVE_SANDBOX_INIT=0
HAVE_STRCASESTR=1
HAVE_STRINGLIST=0
HAVE_STRLCAT=1
HAVE_STRLCPY=1
HAVE_STRNDUP=1
HAVE_STRPTIME=1
HAVE_STRSEP=1
HAVE_STRTONUM=0
HAVE_SYS_ENDIAN=0
HAVE_VASPRINTF=1
EOF
            ./configure
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        mandoc)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        mandoc)
            make install DESTDIR=$package_install_dir
            split_docs
            ;;
        docs)
            install_split
            ;;
        *)
            default_install
            ;;
    esac
}
