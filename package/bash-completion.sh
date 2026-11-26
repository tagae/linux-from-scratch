: ${package_version:=2.18.0}
: ${package_source:=https://github.com/scop/bash-completion/releases/download/$package_version/bash-completion-$package_version.tar.xz}
: ${package_source_hash:=sha256:88bcf85124f77f74f2f2f8bcd16ac4382d807a827ede742a64940c7116aea33f}
: ${package_description:=Programmable completion for the Bash shell.}
: ${package_license:=GPL-2.0-or-later}
# The NVD names no product for it.
: ${package_cpe:=none}

prepare() {
    case $package_component in
        bash-completion)
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                --sysconfdir=/etc
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        bash-completion)
            make
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        bash-completion)
            make install DESTDIR=$package_install_dir
            # The READMEs of the directories that take the completions, helpers and startup files
            # of others are documentation, and all that those directories hold.
            local data=$package_install_dir$prefix/share/bash-completion
            rm -v $data/completions/README.md $data/helpers/README.md $data/startup/README.md
            find $package_install_dir -type d -empty -delete
            # The CMake files, like the pkg-config file, tell builds where completions go.
            move_to_dev_component usr/share/cmake
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
