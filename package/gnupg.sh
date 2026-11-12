: ${package_version:=2.5.24}
: ${package_source:=https://gnupg.org/ftp/gcrypt/gnupg/gnupg-$package_version.tar.bz2}
: ${package_source_hash:=sha256:bf149d01a2b9fcc0e4589b8ae8697d3d5c557ea48ed95a3fa55dd3b1187e6039}
: ${package_description:=OpenPGP encryption and signing tools.}
: ${package_license:=GPL-3.0-or-later AND LGPL-2.1-or-later AND (LGPL-3.0-or-later OR GPL-2.0-or-later)}

prepare() {
    case $package_component in
        gnupg)
            # The CCID driver looks for libusb's header in a list of directories that a sysroot
            # does not move, the first of which stands for the compiler's own search path.
            env ${sysroot:+CPPFLAGS=-I$sysroot/usr/include/libusb-1.0} \
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${sysconfdir:+--sysconfdir=$sysconfdir} \
                ${nls:+--enable-nls=$nls} \
                ${gpgsm:+--enable-gpgsm=$gpgsm} \
                ${dirmngr:+--enable-dirmngr=$dirmngr} \
                ${keyboxd:+--enable-keyboxd=$keyboxd} \
                ${tpm2d:+--enable-tpm2d=$tpm2d} \
                ${wks_tools:+--enable-wks-tools=$wks_tools} \
                ${gpgtar:+--enable-gpgtar=$gpgtar} \
                ${tofu:+--enable-tofu=$tofu} \
                ${photo_viewers:+--enable-photo-viewers=$photo_viewers} \
                ${ccid_driver:+--enable-ccid-driver=$ccid_driver} \
                --disable-tests \
                --disable-doc
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        gnupg)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        gnupg)
            make install DESTDIR=$package_install_dir
            # Programs that no option leaves out, and that neither keys nor cards need: for mail and
            # the Web Key Service, for users' home directories and Windows code signing, and to
            # debug logs, keyboxes and OpenPGP packets.
            local bin=$package_install_dir$prefix/bin sbin=$package_install_dir$prefix/sbin
            rm -v $bin/gpg-mail-tube $bin/gpgparsemail $bin/gpg-wks-client \
                $package_install_dir$prefix/libexec/gpg-wks-client \
                $bin/gpg-authcode-sign.sh $sbin/addgnupghome $sbin/applygnupgdefaults \
                $bin/watchgnupg $bin/gpgsplit $bin/kbxutil
            move_to_dev_component
            move_to_docs_component
            ;;
        *)
            default_install
            ;;
    esac
}
