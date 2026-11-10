: ${package_version:=4.20.2}
: ${package_source:=https://github.com/shadow-maint/shadow/releases/download/$package_version/shadow-$package_version.tar.xz}
: ${package_source_hash:=sha256:b89f432b75ae55a2d852b446d0365484795fdf533ab97d550e325fa15594a224}
: ${package_description:=Login and user account management tools.}
: ${package_license:=BSD-3-Clause AND BSD-2-Clause AND GPL-2.0-or-later AND Unlicense}
: ${package_cpe:=a:debian:shadow:$package_version}

: ${prefix:=/usr}

# configure resets exec_prefix to "" under /usr, which would put login, nologin and libsubid in
# /bin, /sbin and /lib, so the directories derived from it are passed explicitly.
# logind support would need libsystemd, which is built after this package.
# New passwords are hashed with yescrypt, rather than with shadow's default, DES.
# The system has no mail delivery, so login does not check for mail.
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
                --with-group-name-max-length=32 \
                --with-yescrypt \
                ${subordinate_ids:+--enable-subordinate-ids=$subordinate_ids} \
                ${bcrypt:+--with-bcrypt=$bcrypt}
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
            make install DESTDIR=$package_install_dir ${suidperms:+suidperms=$suidperms}
            sed -i -e 's/^#ENCRYPT_METHOD .*/ENCRYPT_METHOD YESCRYPT/' \
                -e 's/^MAIL_CHECK_ENAB[[:space:]].*/MAIL_CHECK_ENAB no/' $package_install_dir/etc/login.defs
            # Without PAM, login prints the file that login.defs' MOTD_FILE names after each login.
            cp -rv $package_files_dir/etc $package_install_dir/
            move_to_dev_component
            ;;
        dev)
            install_component
            ;;
        *)
            default_install
            ;;
    esac
}
