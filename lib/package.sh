build_package() {
    for pkg in "$@"; do
        (
            source_package "$pkg"
            ! is_archived || return 0
            mkdir -p $package_build_dir $package_install_dir
            cd $package_build_dir
            fetch
            prepare
            build
            install
            archive
        )
    done
}

install_package() {
    case "${1:-help}" in
        help)
            echo "Usage: $(basename "$0") install <PACKAGE>..."
            echo ""
            if [ $# -eq 1 ]; then exit 0; else exit 1; fi
            ;;
    esac

    # Build environment shared by every package installed into a platform's target system tree.
    : ${package_variant:=$SYSTEM_KEY}

    # DESTINATION (-d) picks an install location.
    if [ -n "${DESTINATION:-}" ]; then
        if [ -d "$DESTINATION" ]; then
            package_install_dir=$(realpath "$DESTINATION")
        elif [ -f "$DESTINATION" ]; then
            IMAGE="$DESTINATION" image
            package_install_dir=$ROOT_DIR
        elif [ -b "$DESTINATION" ]; then
            DEVICE="$DESTINATION" device
            package_install_dir=$ROOT_DIR
        elif [ "${DESTINATION%.img}" != "$DESTINATION" ]; then
            IMAGE="$DESTINATION" image
            package_install_dir=$ROOT_DIR
        else
            mkdir -pv "$DESTINATION"
            package_install_dir=$(realpath "$DESTINATION")
        fi
    fi

    for pkg in "$@"; do
        (
            source_package "$pkg"
            fetch
            prepare
            build
            install
        )
    done
}

version() {
    (
        source_package $1
        echo $package_version
    )
}

# Executes in the subshell that evaluates package scripts.
# Functions with a leading underscore denote private APIs that packages shouldn't invoke.
source_package() {
    : ${package_name:=${1%#*}}
    : ${package_component=${1#*#}}

    [ -f $package_dir/$package_name.sh ] || bail "Unknown package '$package_name'"

    fetch() {
        default_fetch
    }

    prepare() {
        default_prepare
    }

    build() {
        default_build
    }

    install() {
        default_install
    }

    archive() {
        default_archive
    }

    merge() {
        default_merge
    }

    default_fetch() {
        case ${package_source:-none} in
            https://*.tar.*|https://*.tgz)
                get $package_source ${package_source_hash:-}
                ;;
            https://github.com*|https://git.*)
                git_checkout $package_source $package_branch $package_source_dir
                ;;
            none)
                echo "$package_product: nothing to fetch"
                ;;
            *)
                bail "Unsupported package source: $package_source"
                ;;
        esac
    }

    default_prepare() {
        echo "$package_product: nothing to prepare"
    }

    default_build() {
        echo "$package_product: nothing to build"
    }

    default_install() {
        # If a package exists, it is because there is something to install.
        bail "Unknown package product '$package_product'"
    }

    default_archive() {
        local archive=$ARCHIVE_DIR/$SYSTEM_KEY/$package_archive
        ! [ -f $archive ] || return 0
        mkdir -p $ARCHIVE_DIR/$SYSTEM_KEY
        stage "Archiving $package_archive into $archive"
        tar --owner=0 --group=0 --numeric-owner -cJf $archive -C $package_install_dir .
    }

    is_archived() {
        local archive=$ARCHIVE_DIR/$SYSTEM_KEY/$package_archive
        test -f $archive
    }

    default_merge() {
        stage "Merging $package_archive"
        local archive=$ARCHIVE_DIR/$SYSTEM_KEY/$package_archive
        if command -v xz >/dev/null 2>&1 || [ "${file%.xz}" == "$file" ] ; then
            tar xf $archive -C $package_merge_dir
        else
            # Copy the stage dir straight into the live system.
            tar -C $package_install_dir -cf - . | tar -C $package_merge_dir -xf -
        fi
    }

    patch_source() {
        local url=$1
        local hash=$2 # Expected to be in "algo:hexdigest" form.
        local file=${url##*/}
        mkdir -p $DOWNLOAD_DIR
        [ -f $DOWNLOAD_DIR/$file ] || fetch_url "$url" "$DOWNLOAD_DIR"
        verify_hash "$DOWNLOAD_DIR/$file" "$hash"
        local stamp=$package_source_dir/.patched-$file
        if ! [ -f $stamp ]; then
            ( cd $package_source_dir && patch -N -p 1 -i $DOWNLOAD_DIR/$file )
            touch $stamp
        fi
    }

    fetch_patch() {
        mkdir -p $DOWNLOAD_DIR
        [ -f $DOWNLOAD_DIR/$file ] || fetch_url "$url" "$DOWNLOAD_DIR"
        verify_hash "$DOWNLOAD_DIR/$file" "$hash"
    }

    . $package_dir/$package_name.sh

    case ${package_source:-none} in
        https://*.tar.*|https://*.tgz)
        ;;
        https://github.com*|https://git.*)
            if [ -z "${package_branch:-}" ]; then
                package_branch_file=$WORK_DIR/.$package_name-branch
                if ! [ -s $package_branch_file ]; then
                    mkdir -p $(dirname $package_branch_file)
                    git_default_branch $package_source > $package_branch_file
                fi
                package_branch=$(cat $package_branch_file)
            fi
            : ${package_version:=$package_branch}
            ;;
        none)
            ;;
    esac

    : ${package_release:=$package_name${package_variant:+-$package_variant}-$package_version${package_revision:+-$package_revision}}
    : ${package_files_dir:=$package_dir/$package_name}
    : ${package_source_dir:=$SOURCE_DIR/$package_name-$package_version}
    : ${package_work_dir:=$WORK_DIR/$package_release}
    : ${package_build_dir:=$package_work_dir/build/$package_component}
    : ${package_install_dir:=$package_work_dir/install/$package_component}
    if [ "$package_name" = "$package_component" ]; then
        : ${package_product:=$package_name}
        : ${package_deliverable:=$package_release}
    else
        : ${package_product:=$package_name#$package_component}
        : ${package_deliverable=$package_release-$package_component}
    fi
    : ${package_archive=$package_deliverable.tar.xz}

    readonly package_name package_component \
             package_version package_branch package_release \
             package_source package_source_hash \
             package_files_dir package_source_dir \
             package_work_dir package_build_dir package_install_dir \
             package_product package_deliverable \
             package_archive
}
