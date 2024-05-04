case $platform in
    pi*) : ${package_source:=https://github.com/raspberrypi/linux} ;;
    *)   : ${package_source:=https://git.kernel.org/pub/scm/linux/kernel/git/torvalds/linux} ;;
esac

build() {
    case $package_component in
        kernel)
            todo
            ;;
        *)
            default_build
            ;;
    esac
}

install() {
    case $package_component in
        headers)
            make -C $package_source_dir \
                 ARCH=$ARCH \
                 INSTALL_HDR_PATH=$package_install_dir/usr \
                 headers_install
            ;;
        kernel)
            todo
            ;;
        *)
            default_install
            ;;
    esac
}
