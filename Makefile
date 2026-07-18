.PHONY: \
	tools tools-% \
	system system-% \
	image image-% \
	qemu qemu-% \
	test test-% \
	reinstall-tools reinstall-system \
	clean distclean

# The `test` goal covers the whole chain for the `virt` platform:
# tools, system, image, and emulation.
.DEFAULT_GOAL := test

tools: tools-virt
system: system-virt
image: image-virt
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

image/%.img: system-%
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
