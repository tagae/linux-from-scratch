.PHONY: \
	tools %-tools \
	system %-system \
	image \
	qemu %-qemu \
	test %-test \
	reinstall-tools %-reinstall-tools reinstall-system %-reinstall-system \
	check check-probes check-probe \
	cold-test %-cold-test \
	e2e-test \
	clean distclean \
	FORCE

# Keep intermediate files, in particular image/*.img. Otherwise, they would be deleted.
.SECONDARY:

# The `test` goal covers the whole chain for the `virt` platform:
# tools, system, image, and emulation.
.DEFAULT_GOAL := test

# Whatever depends on FORCE will be considered out of date, since it depends on nothing.
FORCE:

# Flavor: ONE set of rules, parameterized by USERLAND — each value names an umbrella
# (bootable-$USERLAND.sh) that fully describes init AND userland: systemd-busybox (default),
# systemd, busybox. SYSTEM_KEY always includes the flavor, so image names are uniform
# (image/systemd-virt.img) and the rules below need no per-flavor cases.
USERLAND ?= systemd-busybox

# Capabilities: the same interface as lfs (e.g. `make test CAPS="network 9p"`), folded into the one
# rule set exactly like USERLAND above — no per-capability targets. CAPS_KEY mirrors lfs's own
# SYSTEM_KEY folding: sorted, de-duplicated ($(sort) does both, matching `sort -u`), one +<cap> per
# capability — so any spelling of the same set names the same image, and empty CAPS leaves every
# no-caps name byte-identical.
CAPS ?=
empty :=
space := $(empty) $(empty)
CAPS_KEY := $(if $(strip $(CAPS)),+$(subst $(space),+,$(sort $(CAPS))))

tools: virt-tools
system: virt-system
image: image/$(USERLAND)-virt$(CAPS_KEY).img
qemu: virt-qemu
test: virt-test

.env:
	echo HOST_UID=$$(id -u) >> $@
	echo HOST_GID=$$(id -g) >> $@
	echo LFS_RELEASE=r13.0-143-systemd >> $@
	echo DISTRIB_CODENAME=$$(id -un) >> $@
	echo VERSION_CODENAME=$$(id -un) >> $@

# Platform-parameterized rules, named <platform>-<verb> (virt-tools, pi0-test) so they read
# naturally. Each recipe passes its settings inline, so the environment handed to docker
# compose/./lfs/./test is visible right where it is set (and in `make -n` output).
%-tools: .env
	# Chapter 5: Compiling a Cross-Toolchain
	# Chapter 6: Cross Compiling Temporary Tools
	PLATFORM=$* docker compose run --build --rm bootstrap ./lfs tools bootstrap
	# Chapter 7: Building Additional Temporary Tools
	PLATFORM=$* docker compose run --build --rm scratch ./lfs tools build

%-system: %-tools
	# Chapter 8: Installing Basic System Software
	# Chapter 9: System Configuration
	PLATFORM=$* USERLAND=$(USERLAND) CAPS="$(CAPS)" docker compose run --rm scratch ./lfs system build

image/$(USERLAND)-%$(CAPS_KEY).img: %-system FORCE
	# The scratch image has no sudo (no setuid mechanism, no /etc/passwd), so build as root.
	PLATFORM=$* USERLAND=$(USERLAND) CAPS="$(CAPS)" docker compose run --rm --user 0:0 scratch ./lfs image build

%-test: image/$(USERLAND)-%$(CAPS_KEY).img
	./test $* $(USERLAND) "$(CAPS)"

%-qemu: image/$(USERLAND)-%$(CAPS_KEY).img
	PLATFORM=$* USERLAND=$(USERLAND) CAPS="$(CAPS)" ./lfs qemu

# Re-run the install (and downstream) steps against fresh volumes without
# a full from-source rebuild. Keyed per platform (and, for system, per
# USERLAND/CAPS — the same variables as everywhere above), with stamp
# deletion scoped to the phase actually being reinstalled:
#  - %-reinstall-tools: the tools volume is shared by every platform, so
#    dropping it is global, but only tools-phase install stamps (variants
#    tools/pass1-*/<target triple>) are cleared — system-phase
#    stamps stay, since their install trees are untouched.
#  - %-reinstall-system: scoped entirely to one SYSTEM_KEY — its work
#    stamps (install AND archive/merge: the merged tree is being wiped,
#    so tarballs must re-extract), its install tree, and its archive dir
#    (default_archive skips existing tarballs even unstamped).
%-reinstall-tools:
	docker compose run --rm scratch sh -c 'find /var/lfs/work \( -path "*-tools-*" -o -path "*-pass1-*" -o -path "*-scratch-linux-*" \) -name ".install-*" -delete'
	docker volume rm -f linux-from-scratch_tools
	$(MAKE) $*-tools

reinstall-tools: virt-reinstall-tools

%-reinstall-system:
	docker compose run --rm scratch sh -c 'find /var/lfs/work -path "*-$(USERLAND)-$*$(CAPS_KEY)-*" \( -name ".install-*" -o -name ".archive-*" -o -name ".merge-*" \) -delete && rm -rf /var/lfs/install/$(USERLAND)-$*$(CAPS_KEY) /var/lfs/archive/$(USERLAND)-$*$(CAPS_KEY)'
	$(MAKE) $*-system

reinstall-system: virt-reinstall-system

# Fast, deterministic regression suite (no QEMU, no package builds) -- see
# tests/README.md. Separate from `test` above (the slow, real boot-matrix
# harness, which this does not replace and does not run).
check: .env
	@sh tests/run.sh

# Stage 2: functional in-guest probes (boot a real image, assert on live
# behavior) -- see tests/README.md and tests/probes.sh. Separate from
# `check` above ON PURPOSE: this needs QEMU plus already-built images
# (./lfs system build / ./lfs image build for whatever SYSTEM_KEYs the
# probes under tests/probes/ target), and a single probe can take
# minutes where `check` is seconds -- so this never runs implicitly as
# part of `check`, only when asked for explicitly. A probe whose image
# isn't built yet SKIPs rather than failing (see tests/probes.sh).
check-probes: .env
	@sh tests/probes.sh

# Run a single probe: make check-probe PROBE=network
check-probe: .env
	@PROBE=$(PROBE) sh tests/probes.sh

# Periodic COLD build (tests/README.md): distclean wipes EVERY platform's
# build-state volumes (source/work/tools/install) plus local work/image,
# so `%-cold-test` rebuilds the whole tools->system->image->test chain
# from scratch, from nothing but the hash-verified download/ cache --
# warm stamps mask real bugs (see docs/design/packaging.md's own
# gotchas), proven repeatedly. Slow by design (a full `make tools` from
# an empty TOOL_DIR) and global blast radius (distclean is not scoped to
# one platform) -- run occasionally by hand or in CI, never implicitly.
# Clearing download/ too (forcing every source to be re-fetched from
# upstream instead of just rebuilt) is a rarer, network-dependent variant
# left as a manual `rm -rf download && make <platform>-cold-test`.
%-cold-test: distclean
	$(MAKE) $*-test

cold-test: virt-cold-test

# End-to-end self-host proof (docs/design/e2e-cross.md): the virt builder
# guest cross-compiles a pi0 GnuPG image with its OWN aarch64->arm
# cross-toolchain, and the host boots it and generates a keypair with
# separate encryption + authentication subkeys. From a pristine state it
# first assembles the builder image (E1: Debian bootstrap -> tools ->
# builder system + tool payload -> image) — hours by design; against a warm
# builder image the in-guest steps fast-path. Never part of check/test.
e2e-test: .env
	@sh tests/e2e/run.sh

clean:
	docker volume rm -f linux-from-scratch_source linux-from-scratch_work linux-from-scratch_install

distclean:
	docker compose down -v
	rm -rf work/
	rm -f image/*
