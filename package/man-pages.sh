: ${package_version:=6.20}
: ${package_source:=https://www.kernel.org/pub/linux/docs/man-pages/man-pages-$package_version.tar.xz}
: ${package_source_hash:=sha256:180f0d16a2142dd9671760ac0afeadcc25e861f695eb420293e1206a87ca083f}
: ${package_description:=Manual pages of the Linux kernel and the C library.}
# Each page names its licence. The two LicenseRefs are for the notices of older pages that match no
# SPDX licence; ld.so.conf(5) and tunables.conf(5) carry none.
: ${package_license:=Linux-man-pages-copyleft AND Linux-man-pages-copyleft-2-para AND Linux-man-pages-copyleft-var AND Linux-man-pages-1-para AND GPL-1.0-or-later AND GPL-2.0-only AND GPL-2.0-or-later AND GPL-3.0-or-later AND BSD-2-Clause AND BSD-3-Clause AND BSD-4-Clause-UC AND BSD-4.3TAHOE AND MIT AND 0BSD AND Spencer-94 AND LicenseRef-man-pages-Public-Domain AND LicenseRef-man-pages-Freely-Redistributable}
# The NVD names no product for it.
: ${package_cpe:=none}

# The makefiles run without make's built-in rules and variables (-R). The build writes the pages,
# with the release's version in their headers, to `builddir`. GIT=true: the release's pages have
# their dates, which the build otherwise asks git for.
build() {
    make -R -C $package_source_dir builddir=$package_build_dir GIT=true
}

install() {
    make -R -C $package_source_dir builddir=$package_build_dir GIT=true \
        DESTDIR=$package_install_dir prefix=$prefix install-man

    cd $package_install_dir$prefix/share/man
    # The pages that other packages install: libxcrypt's of crypt, shadow's of getspnam and the
    # passwd file, tzdata's of its file format, and mandoc's of the man language.
    rm -v man3/crypt.3 man3/crypt_r.3 man3/getspnam.3 man5/passwd.5 man5/tzfile.5 man7/man.7
    # Of the commands, those of glibc, whose releases have no pages, are what a system holds.
    local page
    for page in man1/* man8/*; do
        case ${page#*/} in
            intro.[18] | getent.1 | pldd.1 | ld.so.8 | ld-linux.8 | ld-linux.so.8 | ldconfig.8 | sln.8) ;;
            *) rm -v $page ;;
        esac
    done
    move_to_docs_component
}
