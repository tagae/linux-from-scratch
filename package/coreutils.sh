: ${package_version:=9.11}
: ${package_source:=https://ftp.gnu.org/gnu/coreutils/coreutils-$package_version.tar.xz}
: ${package_source_hash:=sha256:394024eda0a5955217ceda9cd1201e65dc8fa3aa29c2951135a49521d57c3cc3}
: ${package_description:=GNU core file, text and shell utilities.}
: ${package_license:=GPL-3.0-or-later}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        ${install_program:+--enable-install-program=$install_program} \
        ${no_install_program:+--enable-no-install-program=$no_install_program} \
        ${nls:+--enable-nls=$nls}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir
}
