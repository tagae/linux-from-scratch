: ${package_version:=5.3}
: ${package_source:=https://ftp.gnu.org/gnu/bash/bash-$package_version.tar.gz}
: ${package_source_hash:=sha256:0d5cd86965f869a26cf64f4b71be7b96f90a3ba8b3d74e27e8e9d9d5550f31ba}
: ${package_description:=GNU Bourne-Again shell.}
: ${package_license:=GPL-3.0-or-later}

prepare() {
    case $package_component in
        bash)
            # Readline uses the termcap code in the source, linked statically, unless `termcap_lib`
            # names a library (`ncursesw`): that code reads /etc/termcap, which a system with
            # ncurses lacks. Left to look for a library, configure would link whichever terminal
            # library the sysroot holds, and bash would then depend on what was installed before
            # it. It is told that there is one, and make which.
            if [ -n "${termcap_lib:-}" ]; then bash_termcap=libncurses; else bash_termcap=gnutermcap; fi

            bash_cv_termcap_lib=$bash_termcap \
            $package_source_dir/configure \
                ${host:+--host=$host} \
                ${build:+--build=$build} \
                ${prefix:+--prefix=$prefix} \
                ${bash_malloc:+--with-bash-malloc=$bash_malloc} \
                ${nls:+--enable-nls=$nls}
            ;;
        *)
            default_prepare
            ;;
    esac
}

build() {
    case $package_component in
        bash)
            make ${termcap_lib:+TERMCAP_LIB=-l$termcap_lib}
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        bash)
            # The loadable builtins are examples, many of them duplicating standalone programs, and
            # the headers and makefiles for writing more.
            make install DESTDIR=$package_install_dir SHOBJ_STATUS=unsupported \
                ${termcap_lib:+TERMCAP_LIB=-l$termcap_lib}
            # The tools' sh is this bash; a system's sh is dash's.
            case ${sh_link:-yes} in
                yes) ln -sfv bash $package_install_dir$prefix/bin/sh ;;
            esac
            # bashbug mails bug reports.
            case ${bashbug:-yes} in
                no) rm -v $package_install_dir$prefix/bin/bashbug ;;
            esac
            move_to_docs_component
            ;;
        *)
            default_install
            ;;
    esac
}
