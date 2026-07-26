.PHONY: \
	tools tools-% \
	system system-% \
	image \
	qemu qemu-% \
	test test-% \
	systemd-system systemd-system-% \
	systemd-image \
	systemd-qemu systemd-qemu-% \
	systemd-test systemd-test-% \
	busybox-system busybox-system-% \
	busybox-image \
	busybox-qemu busybox-qemu-% \
	busybox-test busybox-test-% \
	network-system network-image network-qemu network-test \
	reinstall-tools reinstall-system \
	check check-probes check-probe \
	e2e-test \
	clean distclean \
	FORCE

# Whatever depends on FORCE will be considered out of date, since it depends on nothing.
FORCE:

# Keep intermediate files, in particular image/%.img. Otherwise, they would be deleted.
.SECONDARY:

# The `test` goal covers the whole chain for the `virt` platform:
# tools, system, image, and emulation.
.DEFAULT_GOAL := test

tools: tools-virt
system: systemd-system-virt
image: image/virt.img
qemu: systemd-qemu-virt
test: systemd-test-virt

systemd-system: systemd-system-virt
systemd-image:  image/virt.img
systemd-qemu:   systemd-qemu-virt
systemd-test:   systemd-test-virt

# Busybox-init flavor (INIT=busybox): the same chain, a separate install
# tree / boot dir / image (image/busybox-<platform>.img) so it coexists
# with the default systemd flavor.
busybox-system: busybox-system-virt
busybox-image:  image/busybox-virt.img
busybox-qemu:   busybox-qemu-virt
busybox-test:   busybox-test-virt

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

# ---- systemd flavor (the default; image is bare image/<platform>.img) ----
systemd-system-%: tools-%
	# Chapter 8: Installing Basic System Software
	# Chapter 9: System Configuration
	PLATFORM=$* INIT=systemd docker compose run --rm scratch ./lfs system build

image/%.img: systemd-system-% FORCE
	# The scratch image has no sudo (no setuid mechanism, no /etc/passwd), so build as root.
	PLATFORM=$* INIT=systemd docker compose run --rm --user 0:0 scratch ./lfs image build

systemd-test-%: image/%.img
	./test $* systemd

systemd-qemu-%: image/%.img
	PLATFORM=$* INIT=systemd ./lfs qemu

# ---- busybox-init flavor (image is image/busybox-<platform>.img) ----
# Same shape as the systemd rules above; shares the toolchain (tools-%).
busybox-system-%: tools-%
	PLATFORM=$* INIT=busybox docker compose run --rm scratch ./lfs system build

image/busybox-%.img: busybox-system-% FORCE
	# The scratch image has no sudo (no setuid mechanism, no /etc/passwd), so build as root.
	PLATFORM=$* INIT=busybox docker compose run --rm --user 0:0 scratch ./lfs image build

busybox-test-%: image/busybox-%.img
	./test $* busybox

busybox-qemu-%: image/busybox-%.img
	PLATFORM=$* INIT=busybox ./lfs qemu

# ---- opt-in "network" capability (CAPS=network; virt/systemd only for
# now — capabilities are proven here first; a %-pattern version can follow
# once a Pi platform actually has a NIC driver, see network.config) ----
network-system: tools-virt
	PLATFORM=virt INIT=systemd CAPS=network docker compose run --rm scratch ./lfs system build

image/virt+network.img: network-system FORCE
	# The scratch image has no sudo (no setuid mechanism, no /etc/passwd), so build as root.
	PLATFORM=virt INIT=systemd CAPS=network docker compose run --rm --user 0:0 scratch ./lfs image build

network-image: image/virt+network.img

network-test: image/virt+network.img
	./test virt systemd network

network-qemu: image/virt+network.img
	PLATFORM=virt INIT=systemd CAPS=network ./lfs qemu

# ---- unprefixed shortcuts for the default (systemd) flavor ----
# A recipe-less pattern rule can't act as an alias (make then reports "no
# rule to make target"), so these delegate to the systemd-<verb>-% rule via
# a sub-make. Bare `system`/`qemu`/`test` alias the systemd goals directly
# (above), so only the per-platform pattern forms need this.
system-%: ; @$(MAKE) systemd-system-$*
test-%:   ; @$(MAKE) systemd-test-$*
qemu-%:   ; @$(MAKE) systemd-qemu-$*

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
# separate encryption + authentication subkeys. Hours from cold by design;
# needs an already-built virt+9p+loop builder image (E1 is the deferred
# from-pristine step -- see the script). Never runs as part of check/test.
e2e-test:
	@sh tests/e2e/run.sh

clean:
	docker volume rm -f linux-from-scratch_source linux-from-scratch_work linux-from-scratch_install

distclean:
	docker compose down -v
	rm -rf work/
	rm -f image/*
