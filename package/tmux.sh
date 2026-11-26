: ${package_version:=3.8}
: ${package_source:=https://github.com/tmux/tmux/releases/download/$package_version/tmux-$package_version.tar.gz}
: ${package_source_hash:=sha256:e79c699c7e949dccd0a4a125e17b8d1261e311b16979dbc8eb34542f3966d82e}
: ${package_description:=Terminal multiplexer.}
: ${package_license:=ISC AND BSD-2-Clause AND BSD-3-Clause AND SSH-short}
: ${package_cpe:=a:tmux_project:tmux:$package_version}

prepare() {
    case $package_component in
        tmux)
            # default_term is the TERM of what runs in tmux, whose description the system needs.
            # Without it, configure picks the one that it finds by running a program, and `screen`
            # in a cross build, where it can run none.
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${default_term:+--with-TERM=$default_term} \
                --sysconfdir=/etc
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        tmux)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        tmux)
            make install DESTDIR=$package_install_dir
            move_to_docs_component
            ;;
        *)
            default_install
            ;;
    esac
}
