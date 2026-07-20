# p11-kit — provides the `trust` command make-ca shells out to (see
# package/make-ca.sh) to turn per-certificate PKCS#11 anchor files into the
# openssl-directory / pem-bundle trust store outputs. Always a build-host-
# native tool (never shipped to a target tree — see package/ca-certificates.sh
# for how the resulting PEM bundle alone gets copied there instead), so this
# is a plain native meson build: no cross-file, unlike systemd.sh's.
: ${package_version:=0.26.4}
: ${package_source:=https://github.com/p11-glue/p11-kit/releases/download/$package_version/p11-kit-$package_version.tar.xz}
: ${package_source_sha256:=89c3ffb10e076ee036e14732bf6547a1e1c4fb48699a5dee7ceb5ce4f7c0c462}

prepare() {
    # trust_paths: compiled-in fallback anchor directory (module.c's
    # TRUST_PATHS macro) — never actually reached in practice here, since
    # ca-certificates.sh always supplies an explicit "paths=" argument via
    # its own throwaway module config (see there for why: this scratch
    # container never bind-mounts TOOL_DIR onto the real /etc p11-kit's own
    # compiled-in absolute paths point at). Set anyway for documentation/
    # defence in depth.
    #
    # trust_module=enabled (rather than the default 'auto'): fail the build
    # loudly if libtasn1/asn1Parser (installed just before this) somehow
    # aren't found, instead of silently producing a `trust` with no anchor
    # extraction support.
    #
    # env_override_paths=enabled: compiles in P11_SYSTEM_CONFIG_MODULES/
    # P11_PACKAGE_CONFIG_MODULES/P11_MODULE_PATH/etc environment-variable
    # overrides (see p11-kit/modules.c's p11_get_paths_from_env) — the
    # mechanism ca-certificates.sh relies on to point `trust` at each
    # invocation's own DESTDIR-relative anchor directory.
    #
    # systemd/bash_completion/zsh_completion/gtk_doc/man/nls/test: nothing
    # here needs systemd socket activation, shell completions, docs, or
    # translations for a build-time-only CLI tool never exposed to a user;
    # trimming them also avoids needing gtk-doc/xsltproc/gettext's msgfmt on
    # the search path.
    meson setup $package_source_dir \
        ${prefix:+--prefix=$prefix} \
        --buildtype=release \
        -D trust_paths=/etc/pki/anchors \
        -D trust_module=enabled \
        -D libffi=enabled \
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
