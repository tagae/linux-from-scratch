: ${package_version:=3.1.6}
: ${package_source:=https://files.pythonhosted.org/packages/source/j/jinja2/jinja2-$package_version.tar.gz}
: ${package_source_hash:=sha256:0137fb05990d35f1275a587e9aee6d56da821fc83491a0fb838183be43f66d6d}
: ${package_description:=Python templating engine.}
: ${package_license:=BSD-3-Clause}

install() {
    local site_packages=$package_install_dir$prefix/lib/python${python_version%.*}/site-packages

    mkdir -pv $site_packages
    cp -rv $package_source_dir/src/jinja2 $site_packages/
}
