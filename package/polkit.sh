: ${package_version:=128}
: ${package_source:=https://github.com/polkit-org/polkit/archive/refs/tags/$package_version/polkit-$package_version.tar.gz}
: ${package_source_hash:=sha256:6edb06bf1448e49e428f9597a97af6a05d62146dd0b58f86eeaebcee3f5ecfaa}
: ${package_description:=Authorization manager: lets unprivileged programs ask privileged ones to act.}
: ${package_license:=LGPL-2.0-or-later AND LGPL-2.1-or-later}
: ${package_cpe:=a:polkit_project:polkit:$package_version}

prepare() {
    case $package_component in
        polkit)
            # A build directory that meson configured earlier keeps its options and compilers:
            # setup leaves it alone, and ninja regenerates it with the old ones.
            find . -mindepth 1 -delete
            meson_cross_file

            : ${man:=no}

            # GLib's .pc files give the paths of its code generators in the sysroot, which are the
            # platform's (and left out): meson takes them from the cross file instead, and they are
            # the tools'.
            cat > glib.ini <<EOF
[binaries]
glib-mkenums = '$LFS_TOOL_DIR/usr/bin/glib-mkenums'
glib-genmarshal = '$LFS_TOOL_DIR/usr/bin/glib-genmarshal'
glib-compile-resources = '$LFS_TOOL_DIR/usr/bin/glib-compile-resources'
glib-compile-schemas = '$LFS_TOOL_DIR/usr/bin/glib-compile-schemas'
gio-querymodules = '$LFS_TOOL_DIR/usr/bin/gio-querymodules'
gdbus-codegen = '$LFS_TOOL_DIR/usr/bin/gdbus-codegen'
EOF

            # With freedesktop's sysroot rules (CONTRIBUTING.md, Cross-Compiling), meson reads the
            # unit and D-Bus directories as install directories.
            # Sessions come from libsystemd, which finds none where there is no logind: the rules
            # of these systems name users and groups. Nobody authenticates, so there is no PAM; the
            # shadow file is what the helper that would check a password reads.
            env PKG_CONFIG_FDO_SYSROOT_RULES=1 meson setup $package_source_dir \
                --cross-file cross.ini \
                --cross-file glib.ini \
                ${prefix:+--prefix=$prefix} \
                --libdir=lib \
                --sysconfdir=/etc \
                --localstatedir=/var \
                --buildtype=release \
                -Dsession_tracking=logind \
                -Dauthfw=shadow \
                -Dpolkitd_user=polkitd \
                -Dpolkitd_uid=27 \
                -Dintrospection=false \
                -Dexamples=false \
                -Dtests=false \
                -Dman=$([ $man = yes ] && echo true || echo false) \
                -Dgtk_doc=false \
                -Dgettext=false
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        polkit)
            ninja
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        polkit)
            # Outside the root account, the post-install script only says which owners and modes
            # to give: the setuid programs are left out below, and systemd-tmpfiles gives the
            # directory of the rules to the group of the daemon's account.
            DESTDIR=$package_install_dir ninja install
            cd $package_install_dir

            # Nothing authenticates: rules decide, so the setuid programs that run a command as
            # another user (pkexec) and ask a password for the agents (polkit-agent-helper-1), and
            # the units that start it, are left out, as are the account that sysusers.d would
            # make (the daemon's is one of the static ones) and the translations.
            rm -v usr/bin/pkexec usr/lib/polkit-1/polkit-agent-helper-1 \
                usr/lib/systemd/system/polkit-agent-helper@.service \
                usr/lib/systemd/system/polkit-agent-helper.socket \
                usr/lib/sysusers.d/polkit.conf \
                usr/share/polkit-1/actions/org.freedesktop.policykit.policy
            rm -fv usr/share/man/man1/pkexec.1 usr/share/man/man8/polkit-agent-helper.8
            rm -rv usr/share/locale usr/share/gettext

            # The directories of the rules and of the actions are the profile's and systemd's to
            # fill, and systemd-tmpfiles makes the former.
            find . -type d -empty -delete

            move_to_dev_component
            move_to_docs_component
            ;;
        dev)
            install_component
            ;;
        *)
            default_install
            ;;
    esac
}
