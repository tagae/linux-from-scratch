: ${package_version:=4.0.1}
: ${package_source:=https://github.com/openssl/openssl/releases/download/openssl-$package_version/openssl-$package_version.tar.gz}
: ${package_source_hash:=sha256:2db3f3a0d6ea4b59e1f094ace2c8cd536dffb87cdc39084c5afa1e6f7f37dd09}
: ${package_description:=TLS and general-purpose cryptography toolkit.}
: ${package_license:=Apache-2.0}

prepare() {
    case $package_component in
        openssl)
            # Configure cannot guess the platform from a cross compiler: it takes its name, and
            # the prefix of the toolchain's programs. The features to leave out besides the
            # documentation are listed in `disable`.
            local configure_target feature
            configure_target=${host:+$(_target $host)}
            for feature in ${disable:-}; do
                set -- "$@" no-$feature
            done
            $package_source_dir/Configure \
                $configure_target \
                ${host:+--cross-compile-prefix=$host-} \
                ${prefix:+--prefix=$prefix} \
                --openssldir=/etc/ssl \
                --libdir=lib \
                "$@" \
                no-docs \
                shared
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        openssl)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        openssl)
            make DESTDIR=$package_install_dir install_sw
            rm -fv $package_install_dir/$prefix/lib/libcrypto.a \
                   $package_install_dir/$prefix/lib/libssl.a
            # A native build, which is a tool for the build machine, keeps its development files
            # in place.
            if [ -n "${host:-}" ]; then
                move_to_dev_component usr/lib/cmake
            fi
            # Left empty by the programs and the legacy provider that were not built.
            find $package_install_dir -type d -empty -delete
            # The directories for certificates and configuration, which start out empty.
            case ${ssldirs:-yes} in
                yes) make DESTDIR=$package_install_dir install_ssldirs ;;
            esac
            ;;
        dev)
            install_component
            ;;
        *)
            default_install
            ;;
    esac
}

# The name of the platform in Configure's list, from the architecture of a triplet.
_target() {
    case ${1%%-*} in
        aarch64) echo linux-aarch64 ;;
        arm*) echo linux-armv4 ;;
        x86_64) echo linux-x86_64 ;;
        *) bail "No OpenSSL platform for '$1'" ;;
    esac
}
