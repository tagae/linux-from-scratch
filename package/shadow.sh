: ${package_version:=4.19.4}
: ${package_source:=https://github.com/shadow-maint/shadow/releases/download/$package_version/shadow-$package_version.tar.xz}
: ${package_source_hash:=sha256:ce57a313e315a0a7cb04a8f50cc20753e994e487bbe9b78a2a824ca75cb486c0}
: ${package_description:=Login and user account management tools.}
: ${package_license:=BSD-3-Clause AND BSD-2-Clause AND GPL-2.0-or-later AND Unlicense}

: ${prefix:=/usr}

# configure resets exec_prefix to "" under /usr, which would put login, nologin and libsubid in
# /bin, /sbin and /lib, so the directories derived from it are passed explicitly.
# logind support would need libsystemd, which is built after this package.
prepare() {
    case $package_component in
        shadow)
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                --prefix=$prefix \
                --bindir=$prefix/bin \
                --sbindir=$prefix/sbin \
                --libdir=$prefix/lib \
                --sysconfdir=/etc \
                ${nls:+--enable-nls=$nls} \
                --disable-static \
                --disable-logind \
                --without-libpam \
                --without-libbsd \
                --without-su \
                --with-group-name-max-length=32 \
                ${bcrypt:+--with-bcrypt=$bcrypt} \
                ${yescrypt:+--with-yescrypt=$yescrypt}
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        shadow)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        shadow)
            make install DESTDIR=$package_install_dir
            split_dev_files
            ;;
        dev)
            install_split
            ;;
        *)
            default_install
            ;;
    esac
}
