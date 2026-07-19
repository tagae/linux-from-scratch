.PHONY: \
	tools tools-% \
	system system-% \
	image \
	qemu qemu-% \
	test test-% \
	reinstall-tools reinstall-system \
	clean distclean \
	FORCE

# GNU Make quirk, confirmed by isolated repro: a *pattern-rule* target with a
# phony prerequisite (image/%.img: system-%) only reliably rebuilds while the
# target file doesn't exist yet — once image/pi4.img is sitting on disk, make
# treats it as up to date and never re-checks system-%, even though system-%
# is phony and "always" out of date. A *literal* (non-pattern) target with the
# same phony prerequisite doesn't have this problem — only patterns do. Adding
# an explicit FORCE prerequisite (below) sidesteps it: FORCE itself has no
# file, so make can never treat image/%.img as up to date relative to it.
FORCE:

# Bare — NOT ".SECONDARY: image/%.img tools-% system-%". Confirmed by
# isolated repro: unlike .PHONY, .SECONDARY's prerequisite list does not
# match "%" against instantiated names at all — a scoped/pattern form
# silently protects nothing. It only looks like it works if you test it by
# requesting image/pi4.img directly on the command line, since an explicitly
# -requested goal is never auto-deleted regardless of .SECONDARY — but
# qemu-%/test-% request it *transitively* (qemu-pi4 -> image/pi4.img), and
# in that shape the scoped form lets make delete image/%.img itself plus
# tools-%/system-% right after a successful build (the tools-%/system-%
# deletion attempt fails outright, since those names never correspond to a
# real file). Bare .SECONDARY (protect every target here) is the only form
# that's actually effective.
.SECONDARY:

# The `test` goal covers the whole chain for the `virt` platform:
# tools, system, image, and emulation.
.DEFAULT_GOAL := test

tools: tools-virt
system: system-virt
# image/virt.img, not image-virt: unlike tools-%/system-%/qemu-%/test-%,
# there's no image-% pattern rule — image/%.img (a real file) is it.
image: image/virt.img
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
	PLATFORM=$*	docker compose run --rm scratch ./lfs system build

image/%.img: system-% FORCE
	# The scratch image has no sudo (no setuid mechanism, no /etc/passwd), so build as root.
	PLATFORM=$* docker compose run --rm --user 0:0 scratch ./lfs image build

test-%: image/%.img
	./test $*

qemu-%: image/%.img
	PLATFORM=$* ./lfs qemu

reinstall-tools:
	docker compose run --rm scratch find work -name '.install-*' -delete
	docker volume rm -f linux-from-scratch_tools
	$(MAKE) tools

reinstall-system:
	docker compose run --rm scratch find work -name '.install-*' -delete
	docker volume rm -f linux-from-scratch_install
	$(MAKE) system

clean:
	docker volume rm -f linux-from-scratch_source linux-from-scratch_work linux-from-scratch_install

distclean:
	docker compose down -v
	rm -rf work/
	rm -f image/*
