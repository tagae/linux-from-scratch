.PHONY: \
	tools system image all \
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
	docker compose run --rm scratch ./lfs image build

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
