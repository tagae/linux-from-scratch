install() {
    case "${1:-help}" in
        help)
            echo "Usage: $(basename "$0") install <PACKAGE>..."
            echo ""
            if [ $# -eq 1 ]; then exit 0; else exit 1; fi
            ;;
    esac

    # Establish the build environment for installing INTO a platform's
    # target system tree ($INSTALL_DIR/$PLATFORM) — what a bare
    # `./lfs install <pkg>` means, and what the system build and any
    # umbrella package rely on. Skipped when a caller has already chosen a
    # scenario by presetting package_install_dir: lib/tools.sh's
    # build_tools() sets it to $TOOL_DIR for build-host-native tooling
    # (same scratch phase, but not a target install). The bootstrap phase
    # (tools bootstrap) never reaches install() as a target scenario.
    if [ "${LFS_PHASE:-}" = scratch ] && [ -z "${package_install_dir:-}" ]; then
        target_build_env
    fi

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

    require "$@"
}

# Build and install one or more packages. Public: this is the worker
# behind the `install` command, and an umbrella package's depends() calls
# it to pull in its members (optionally with knob prefixes, e.g.
# `manpages=no require kmod`) — exactly as build_tools()/a system build
# drive installs. Each package builds in its own subshell with freshly
# derived package_* paths (see _source); ambient knobs (host, prefix,
# package_install_dir, package_variant, CC, …) are inherited from the
# caller, so an umbrella sets a member's scenario simply by prefixing.
require() {
    for pkg in "$@"; do
        (
            _source "$pkg"
            stage "$package_product"
            _install
        )
    done
}

# The build environment shared by every package installed into a
# platform's target system tree. Set once per install scenario (by
# install() for a bare invocation; inherited by an umbrella's members),
# so no package carries its own copy — this generalizes what the old
# package/_cross.sh did for the gnupg family alone. Defaults only ( := ),
# so a caller (or -d DESTINATION handling above) can still override.
target_build_env() {
    : ${host:=$target}
    : ${prefix:=/usr}
    # SYSTEM_KEY, not bare $PLATFORM: it carries the init flavor too (see
    # lfs), so a busybox tree and a systemd tree for the same platform get
    # separate stamps and install dirs. Equal to $PLATFORM for the default
    # (systemd) flavor, so existing builds are unaffected.
    : ${package_variant:=$SYSTEM_KEY}
    : ${package_install_dir:=$INSTALL_DIR/$SYSTEM_KEY}
}

# Compile against the packages already installed into the target system
# tree ($INSTALL_DIR/$PLATFORM) rather than the toolchain's own default
# sysroot. A package opts in (from its own script) when it links a library
# an earlier package installed there — util-linux's libtool relink, the
# gnupg family — see project-system-sysroot for the ld-script rationale.
# No-op unless building for the cross target (host=$target), so the same
# call is harmless where build_tools() reuses these scripts natively.
target_sysroot_cc() {
    [ "${host:-}" = "$target" ] || return 0
    if [ -z "${CC:-}" ]; then
        CC="$target-gcc --sysroot=$INSTALL_DIR/$SYSTEM_KEY -idirafter $TOOL_DIR/$target/usr/include"
    fi
    export CC
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
    # Clear any package_* left over from an enclosing package: an umbrella
    # calls require() for its members from within its own subshell, so
    # without this the umbrella's own name/version/paths would be inherited
    # and, being already set, shadow each member's own values (the defaults
    # below only assign when unset). package_install_dir and
    # package_variant are deliberately NOT cleared — they are the ambient
    # install scenario, meant to carry from an umbrella (or build_tools /
    # tools) down to every member.
    unset package_name package_component package_version package_branch \
          package_source package_source_sha256 \
          package_release package_files_dir package_source_dir \
          package_work_dir package_build_dir package_product \
          package_deliverable package_archive package_meta

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
        # Dependencies first. For a meta/umbrella package (package_meta=yes)
        # depends() is the whole recipe — it require()s the members and
        # there is no payload of its own. Run every time (unstamped) so a
        # rebuild re-checks the whole set; each member is still fast-pathed
        # by its own install stamp. For an ordinary package depends() is the
        # no-op default below.
        depends
        [ "${package_meta:-}" = yes ] && return 0
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

    # Overridden by umbrella packages (see package_meta) to require() their
    # members; a no-op for ordinary packages.
    depends() {
        :
    }

    default_fetch() {
        case ${package_source:-none} in
            https://*.tar.*|https://*.tgz)
                get $package_source ${package_source_sha256:-}
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
        [ -f $DOWNLOAD_DIR/$file ] || fetch_url "$url" "$DOWNLOAD_DIR"
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

    # NOTE: package API variables are deliberately NOT frozen readonly here.
    # An umbrella calls require() from within its own subshell, whose child
    # (the member's) _source must be able to clear and re-derive them (see
    # the unset at the top of this function); readonly would propagate into
    # that child and make the clear fail. lib/tools.sh still freezes the few
    # it depends on (package_variant, package_install_dir, …) in its own
    # per-stage subshells where it needs that guarantee.
}
