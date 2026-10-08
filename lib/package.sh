lfs_archive_package() {
    (
        lfs_fetch_dependencies "$1"
        lfs_source_package "$1"
        if ! is_archived; then
            fetch

            mkdir -pv $package_build_dir
            cd $package_build_dir
            prepare
            build

            package_install_dir=$package_stage_dir
            mkdir -pv $package_install_dir
            install

            archive
        fi
        local archive=$(archive_filename)
        echo "${archive#"$ARCHIVE_DIR"/}"
    )
}

lfs_install_package() {
    lfs_archive_package "$1"
    (
        lfs_source_package "$1"
        unarchive
    )
}

lfs_package_version() {
    (
        lfs_source_package $1
        echo $package_version
    )
}

# Fetches a package's source and prints its location.
lfs_fetch_package() {
    (
        lfs_source_package "$1"
        fetch >&2
        echo $package_source_dir
    )
}

# Fetches the sources from a package's `package_fetch_dependencies`,
# exposing each one's location as `<dependency>_source_dir`.
lfs_fetch_dependencies() {
    local dependency source_dir
    for dependency in $(lfs_source_package "$1"; echo ${package_fetch_dependencies:-}); do
        source_dir=$(lfs_fetch_package $dependency)
        eval "${dependency}_source_dir=\$source_dir"
    done
}

# Executes in the subshell that evaluates package scripts.
# Functions with a leading underscore denote private APIs that packages shouldn't invoke.
lfs_source_package() {
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

    unarchive() {
        default_unarchive
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

    archive_filename() {
        echo $ARCHIVE_DIR/$SYSTEM_KEY/$package_archive
    }

    default_archive() {
        local archive=$(archive_filename)
        mkdir -pv $(dirname $archive)
        tar --owner=0 --group=0 --numeric-owner -cJf $archive -C $package_install_dir .
    }

    is_archived() {
        test -f "$(archive_filename)"
    }

    default_unarchive() {
        local archive=$(archive_filename)
        mkdir -pv $package_install_dir
        tar xf $archive -C $package_install_dir
    }

    patch_source() {
        local url=$1
        local hash=$2 # Expected to be in "algo:hexdigest" form.
        local file=${url##*/}
        mkdir -p $DOWNLOAD_DIR
        [ -f $DOWNLOAD_DIR/$file ] || fetch_url "$url" "$DOWNLOAD_DIR"
        verify_hash "$DOWNLOAD_DIR/$file" "$hash"
        local stamp=$package_source_dir/.patched-$file
        ! [ -f $stamp ] || return 0
        ( cd $package_source_dir && patch -N -p 1 -i $DOWNLOAD_DIR/$file ) || {
            # Discard half-patched source so that the next run re-extracts the pristine source.
            rm -rf "${package_source_dir:?}"
            bail "Failed to apply $file; discarded $package_source_dir"
        }
        touch $stamp
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
    : ${package_work_dir:=$WORK_DIR/$SYSTEM_KEY/$package_release}
    : ${package_build_dir:=$package_work_dir/build/$package_component}
    : ${package_stage_dir:=$package_work_dir/stage/$package_component}
    : ${package_install_dir:=$package_stage_dir}
    if [ "$package_name" = "$package_component" ]; then
        : ${package_product:=$package_name}
        : ${package_deliverable:=$package_release}
    else
        : ${package_product:=$package_name#$package_component}
        : ${package_deliverable=$package_release-$package_component}
    fi
    : ${package_archive=$package_deliverable.tar.xz}

    # `package_install_dir` is the only writable var from the package API.
    readonly package_name package_component \
             package_version package_branch package_release \
             package_source package_source_hash package_fetch_dependencies \
             package_files_dir package_source_dir \
             package_work_dir package_build_dir \
             package_archive \
             package_product package_deliverable
}
