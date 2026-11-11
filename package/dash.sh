: ${package_version:=0.5.13.5}
# Debian's orig tarball is upstream's release tarball, byte for byte (same hash). Upstream's own server,
# https://gondor.apana.org.au/~herbert/dash/files/, does not answer on HTTPS.
: ${package_source:=https://deb.debian.org/debian/pool/main/d/dash/dash_$package_version.orig.tar.gz}
: ${package_source_hash:=sha256:40090101a2a491f13e901d3d48e90414f26634628b9bfff35ff540363c227a7d}
: ${package_description:=Debian Almquist shell, a small POSIX shell.}
# The GPL is that of mksignames.c, a program that generates the list of signal names that dash links,
# and is not linked itself.
: ${package_license:=BSD-3-Clause AND GPL-2.0-or-later}
: ${package_cpe:=a:dash_project:dash:$package_version}

# When cross compiling, configure builds the programs that generate dash's parser tables and signal
# names (mkinit, mknodes, mksyntax, mksignames) with CC_FOR_BUILD, which it takes from `cc` unless
# told: the build machine's compiler here is gcc.
prepare() {
    case $package_component in
        dash)
            CC_FOR_BUILD=gcc \
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix}
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        dash)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        dash)
            make install DESTDIR=$package_install_dir
            ln -sfv dash $package_install_dir$prefix/bin/sh
            move_to_docs_component
            ;;
        *)
            default_install
            ;;
    esac
}
