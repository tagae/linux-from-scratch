install() {
    case "${1:-help}" in
        help)
            echo "Usage: $(basename "$0") install <PACKAGE>..."
            echo ""
            if [ $# -eq 1 ]; then exit 0; else exit 1; fi
            ;;
    esac

    if [ -z "${DESTINATION:-}" ]; then
        true
    elif [ -d "$DESTINATION" ]; then
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

    for pkg in "$@"; do
        (
            _source "$pkg"
            stage "$package_product"
            _install
        )
    done
}

version() {
    (
        _source $1
        echo $package_version
    )
}

fetch() {
    (
        _source $1
        fetch
    )
}

archive() {
    (
        _source $1
        stage "$package_product"
        _archive
    )
}

unarchive() {
    echo "Unarchiving $1 on $INSTALL_DIR..."
    tar xf $1 -C $INSTALL_DIR
}

# This function executes in the subshell that evaluates package scripts.
# Hence, whatever it defines will be available only in the subshell.
# Functions with a leading underscore denote private API that packages shouldn't invoke.
_source() {
    : ${package_name:=${1%#*}}
    : ${package_component=${1#*#}}

    [ -f $PACKAGE_DIR/$package_name.sh ] || bail "Unknown package '$package_name'"

    _once() {
        local step=$1
        if [ -f $package_build_dir/.$step-$package_component ]; then
            echo "$step (done)"
        else
            $step && touch $package_build_dir/.$step-$package_component
        fi
    }

    _install() {
        mkdir -p $package_build_dir $package_install_dir
        cd $package_build_dir
        ( _once fetch; )
        ( _once prepare; )
        ( _once build; )
        ( _once install; )
    }

    _archive() {
        stage "Archiving $package_product"
        _install
        archive
    }

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

    default_fetch() {
        case ${package_source:-none} in
            https://*.tar.*|https://*.tgz)
                get $package_source
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
        ! [ -f $package_archive ] || return 0
        mkdir -p $(dirname $package_archive)
        echo "Expanding $package_archive..."
        tar cjf $ARCHIVE_DIR/$PLATFORM/$package_archive -C $package_install_dir .
    }

    patch_source() {
        local url=$1
        local file=${url##*/}
        mkdir -p $DOWNLOAD_DIR
        [ -f $DOWNLOAD_DIR/$file ] || wget --no-check-certificate -P $DOWNLOAD_DIR $url
        patch -d $package_source_dir -Np1 -i $DOWNLOAD_DIR/$file
    }

    . $PACKAGE_DIR/$package_name.sh

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
    : ${package_files_dir:=$PACKAGE_DIR/$package_name}
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

    # freeze package API variables
    readonly package_name
    readonly package_version
    readonly package_variant
    readonly package_component
    readonly package_product
    readonly package_release
    readonly package_source_dir
    readonly package_work_dir
    readonly package_build_dir
    readonly package_install_dir
    readonly package_deliverable
    readonly package_archive
}
