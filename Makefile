.PHONY: \
	all tools system image \
	qemu qemu-raspi0 qemu-raspi4b test \
	reinstall-tools reinstall-system \
	clean distclean

.DEFAULT_GOAL := all

.env:
	echo HOST_UID=$$(id -u) >> $@
	echo HOST_GID=$$(id -g) >> $@
	echo LFS_RELEASE=r13.0-143-systemd >> $@
	echo DISTRIB_CODENAME=$$(id -un) >> $@
	echo VERSION_CODENAME=$$(id -un) >> $@

tools: .env
	# Chapter 5: Compiling a Cross-Toolchain
	# Chapter 6: Cross Compiling Temporary Tools
	docker compose run --build --rm bootstrap ./lfs tools bootstrap
	# Chapter 7: Building Additional Temporary Tools
	docker compose run --build --rm scratch ./lfs tools build

system:
	# Chapter 8: Installing Basic System Software
	# Chapter 9: System Configuration
	docker compose run --rm scratch ./lfs system build

image:
	# losetup/mount/mkfs/etc. need real root, not just a privileged
	# container — the scratch image has no sudo (no setuid mechanism, no
	# /etc/passwd), so run this one as root directly instead.
	docker compose run --rm --user 0:0 scratch ./lfs image build

qemu:
	./lfs qemu

# Both expect `PLATFORM=pi0` / `PLATFORM=pi4 make tools system image` to
# have already been run for that platform — same convention as `tools`/
# `system`/`image` above, which also read PLATFORM from the environment
# rather than taking it as a target parameter.
qemu-raspi0:
	PLATFORM=pi0 ./lfs qemu

qemu-raspi4b:
	PLATFORM=pi4 ./lfs qemu

test:
	./test-virt

all: tools system image

reinstall-tools:
	docker compose run --rm scratch find work -name '.install-*' -delete
	docker volume rm -f linux-from-scratch_tools
	make tools

reinstall-system:
	docker compose run --rm scratch find work -name '.install-*' -delete
	docker volume rm -f linux-from-scratch_install
	make system

clean:
	docker volume rm -f linux-from-scratch_source linux-from-scratch_work linux-from-scratch_install

distclean:
	docker compose down -v
	rm -rf work/
	rm image/*
