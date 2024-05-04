platform() {
    readonly platform=$1
    [ -f lib/platform/"$platform".sh ] || bail "Unsupported platform '$platform'"

    export LC_ALL=POSIX
    export MAKEFLAGS=-j$(nproc)
    readonly LC_ALL MAKEFLAGS

    if ! [ -x $DOWNLOAD_DIR/config.guess ]; then
        mkdir -p $DOWNLOAD_DIR
        wget -O $DOWNLOAD_DIR/config.guess 'https://git.savannah.gnu.org/gitweb/?p=config.git;a=blob_plain;f=config.guess;hb=HEAD'
        chmod +x $DOWNLOAD_DIR/config.guess
    fi

    # https://www.gnu.org/software/automake/manual/html_node/Cross_002dCompilation.html
    readonly build=$($DOWNLOAD_DIR/config.guess)
    : ${host:=$build}
    : ${target:=$build}

    . lib/platform/$platform.sh
}

install() {
    (
        _source $1
        stage "$package_product"
        _install
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
    tar xf $1 -C $sysroot
}

# This function executes in the subshell that evaluates package scripts.
# Hence, whatever it defines will be available only in the subshell.
# Functions with a leading underscore denote private API that packages shouldn't inovke.
_source() {
    : ${package_name:=${1%#*}}
    : ${package_component=${1#*#}}

    [ -f $PACKAGE_DIR/$package_name.sh ] || die 1 "Unknown package '$package_name'"

    _once() {
        local step=$1
        if [ -f .$step-$package_component ]; then
            echo "$step (done)"
        else
            $step
            touch .$step-$package_component
        fi
    }

    _install() {
        mkdir -p $package_build_dir
        cd $package_build_dir

        _once fetch
        _once prepare
        _once build
        _once install
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
        case $package_source in
            https://github.com*)
                git_checkout $package_source $package_branch $package_source_dir
                ;;
            https://*.tar.*)
                get $package_source
                ;;
            *)
                die 1 "Unsupported package source: $package_source"
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
        bail "Unknown package product '$package_product'"
    }

    default_archive() {
        ! [ -f $package_archive ] && return 0
        mkdir -p $(dirname $package_archive)
        tar cjf $ARCHIVE_DIR/$PLATFORM/$package_archive -C $package_install_dir .
    }

    . $PACKAGE_DIR/$package_name.sh

    case $package_source in
        https://github.com*)
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
    esac

    : ${package_release:=$package_name${package_variant:+-$package_variant}-$package_version${package_revision:+-$package_revision}}
    : ${package_source_dir:=$SOURCE_DIR/$package_name-$package_version}
    : ${package_work_dir:=$WORK_DIR/$package_release}
    : ${package_build_dir:=$package_work_dir/build}
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
