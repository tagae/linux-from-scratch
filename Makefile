.PHONY: \
	tools %-tools \
	system %-system \
	image \
	qemu %-qemu \
	test %-test \
	clean distclean \
	FORCE

# Keep all intermediate files, in particular image/*.img. Otherwise, make deletes them.
.SECONDARY:

# The `test` goal covers the whole chain for the `virt` platform:
# tools, system, image, and emulation.
.DEFAULT_GOAL := test

# Whatever depends on FORCE will be considered out of date, since it depends on nothing.
FORCE:

USERLAND ?= systemd

CAPS ?=
empty :=
space := $(empty) $(empty)
CAPS_KEY := $(if $(strip $(CAPS)),+$(subst $(space),+,$(sort $(CAPS))))

.env:
	@echo HOST_UID=$$(id -u) >> $@
	@echo HOST_GID=$$(id -g) >> $@
	@echo LFS_RELEASE=r13.0-143-systemd >> $@
	@echo DISTRIB_CODENAME=$$(id -un) >> $@
	@echo VERSION_CODENAME=$$(id -un) >> $@

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

tools: virt-tools
system: virt-system
image: image/$(USERLAND)-virt$(CAPS_KEY).img
qemu: virt-qemu
test: virt-test

clean:
	docker volume rm -f $(CURDIR)_source $(CURDIR)_work $(CURDIR)_install

distclean: .env
	docker compose down -v
	rm -rf .env archive/* download/* image/* work/
