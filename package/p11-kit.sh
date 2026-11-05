: ${package_version:=0.26.5}
: ${package_source:=https://github.com/p11-glue/p11-kit/releases/download/$package_version/p11-kit-$package_version.tar.xz}
: ${package_source_hash:=sha256:f2cc09111e44bf3fea58f023180b33acea90aa82d042d6fbb623fbc5ba033bb7}
: ${package_description:=PKCS#11 module loader and trust store tools.}
: ${package_license:=BSD-3-Clause}

prepare() {
    meson setup $package_source_dir \
        ${prefix:+--prefix=$prefix} \
        --libdir=lib \
        --buildtype=release \
        -D trust_paths=/etc/pki/anchors \
        -D trust_module=enabled \
        -D libffi=disabled \
        -D hash_impl=internal \
        -D env_override_paths=enabled \
        -D systemd=disabled \
        -D bash_completion=disabled \
        -D zsh_completion=disabled \
        -D gtk_doc=false \
        -D man=false \
        -D nls=false \
        -D test=false
}

build() {
    ninja
}

install() {
    DESTDIR=$package_install_dir ninja install
}
