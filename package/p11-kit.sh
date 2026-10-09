: ${package_version:=0.26.4}
: ${package_source:=https://github.com/p11-glue/p11-kit/releases/download/$package_version/p11-kit-$package_version.tar.xz}
: ${package_source_hash:=sha256:89c3ffb10e076ee036e14732bf6547a1e1c4fb48699a5dee7ceb5ce4f7c0c462}
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
