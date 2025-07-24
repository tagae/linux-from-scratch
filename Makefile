.PHONY: default check clean distclean pristine tools base

OS_NAME := $(shell uname -s)

ifeq ($(OS_NAME), Darwin)
	.DEFAULT_GOAL := tools
else
	.DEFAULT_GOAL := tools
endif

tools:
	./lfs tools

base:
	./lfs install system-files linux boot#cmdline

clean:
	git clean -dxf work

distclean: clean
	git clean -dxf tools install
	(! test -d /Volumes/LFS) || diskutil eject /Volumes/LFS
	rm -f lfs.sparseimage

pristine:
	rm -rf source/linux-*
	git clean -dxf

docker-sh:
	HOST_UID=$$(id -u) HOST_GID=$$(id -g) docker compose run --rm --build alpine

docker-clean:
	docker volume rm -f linux-from-scratch_tools linux-from-scratch_work linux-from-scratch_install

docker-distclean: docker-clean
	docker volume rm -f linux-from-scratch_source

image/%.img:
	./lfs image $*

# glibc must be built in a case-sensitive filesystem
all-macos:
	test -f lfs.sparseimage || hdiutil create -size 8g -fs 'Case-sensitive APFS' -type SPARSE -volname LFS lfs
	open lfs.sparseimage
	sleep 2
	mkdir -p /Volumes/LFS/work
	WORK_DIR=/Volumes/LFS/work make default
