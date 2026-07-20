: ${package_version:=4.19.4}
: ${package_source:=https://github.com/shadow-maint/shadow/releases/download/$package_version/shadow-$package_version.tar.xz}
: ${package_source_sha256:=ce57a313e315a0a7cb04a8f50cc20753e994e487bbe9b78a2a824ca75cb486c0}

prepare() {
    $package_source_dir/configure \
        ${host:+--host=$host} \
        ${build:+--build=$build} \
        ${prefix:+--prefix=$prefix} \
        --sysconfdir=/etc \
        --disable-static \
        ${bcrypt:+--with-bcrypt=$bcrypt} \
        ${ycrypt:+--with-ycrypt=$ycrypt} \
        ${libbsd:+--with-libbsd=$libbsd} \
        ${audit:+--with-audit=$audit} \
        ${selinux:+--with-selinux=$selinux} \
        ${acl:+--with-acl=$acl} \
        ${attr:+--with-attr=$attr} \
        ${skey:+--with-skey=$skey} \
        ${tcpwrappers:+--with-tcpwrappers=$tcpwrappers}
}

build() {
    make
}

install() {
    make install DESTDIR=$package_install_dir

    # Make passwd and newgrp suid
    chmod -v u+s $package_install_dir/usr/bin/passwd

    # Remove su (use util-linux's su instead)
    rm -fv $package_install_dir/usr/bin/su

    # Create /etc/shadow and /etc/gshadow with proper permissions
    touch $package_install_dir/etc/shadow $package_install_dir/etc/gshadow
    chmod 640 $package_install_dir/etc/shadow $package_install_dir/etc/gshadow
}
