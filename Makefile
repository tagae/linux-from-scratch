.PHONY: \
	tools tools-% \
	system system-% \
	image \
	qemu qemu-% \
	test test-% \
	network-system network-image network-qemu network-test \
	reinstall-tools reinstall-system \
	check check-probes check-probe \
	e2e-test \
	clean distclean \
	FORCE

# Whatever depends on FORCE will be considered out of date, since it depends on nothing.
FORCE:

# Keep intermediate files, in particular image/*.img. Otherwise, they would be deleted.
.SECONDARY:

# The `test` goal covers the whole chain for the `virt` platform:
# tools, system, image, and emulation.
.DEFAULT_GOAL := test

# Flavor: ONE set of rules, parameterized by INIT — each value names an
# umbrella (bootable-$INIT.sh) that fully describes init AND userland:
# systemd-busybox (default), systemd-coreutils (busybox-free GNU
# userland), busybox. SYSTEM_KEY always includes the flavor, so
# image names are uniform (image/systemd-coreutils-virt.img) and the
# rules below need no per-flavor cases.
INIT ?= systemd-busybox

tools: tools-virt
system: system-virt
image: image/$(INIT)-virt.img
qemu: qemu-virt
test: test-virt

.env:
	echo HOST_UID=$$(id -u) >> $@
	echo HOST_GID=$$(id -g) >> $@
	echo LFS_RELEASE=r13.0-143-systemd >> $@
	echo DISTRIB_CODENAME=$$(id -un) >> $@
	echo VERSION_CODENAME=$$(id -un) >> $@

tools-%: .env
	# Chapter 5: Compiling a Cross-Toolchain
	# Chapter 6: Cross Compiling Temporary Tools
	PLATFORM=$* docker compose run --build --rm bootstrap ./lfs tools bootstrap
	# Chapter 7: Building Additional Temporary Tools
	PLATFORM=$* docker compose run --build --rm scratch ./lfs tools build

system-%: tools-%
	# Chapter 8: Installing Basic System Software
	# Chapter 9: System Configuration
	PLATFORM=$* INIT=$(INIT) docker compose run --rm scratch ./lfs system build

image/$(INIT)-%.img: system-% FORCE
	# The scratch image has no sudo (no setuid mechanism, no /etc/passwd), so build as root.
	PLATFORM=$* INIT=$(INIT) docker compose run --rm --user 0:0 scratch ./lfs image build

test-%: image/$(INIT)-%.img
	./test $* $(INIT)

qemu-%: image/$(INIT)-%.img
	PLATFORM=$* INIT=$(INIT) ./lfs qemu

# ---- opt-in "network" capability (CAPS=network; virt/systemd only for
# now — capabilities are proven here first; folding CAPS into the
# parameterized rules above the same way INIT was is the recorded
# follow-on) ----
network-system: tools-virt
	PLATFORM=virt INIT=systemd-busybox CAPS=network docker compose run --rm scratch ./lfs system build

image/systemd-busybox-virt+network.img: network-system FORCE
	# The scratch image has no sudo (no setuid mechanism, no /etc/passwd), so build as root.
	PLATFORM=virt INIT=systemd-busybox CAPS=network docker compose run --rm --user 0:0 scratch ./lfs image build

network-image: image/systemd-busybox-virt+network.img

network-test: image/systemd-busybox-virt+network.img
	./test virt systemd-busybox network

network-qemu: image/systemd-busybox-virt+network.img
	PLATFORM=virt INIT=systemd-busybox CAPS=network ./lfs qemu

reinstall-tools:
	docker compose run --rm scratch find work -name '.install-*' -delete
	docker volume rm -f linux-from-scratch_tools
	$(MAKE) tools

reinstall-system:
	docker compose run --rm scratch find work -name '.install-*' -delete
	docker volume rm -f linux-from-scratch_install
	$(MAKE) system

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
