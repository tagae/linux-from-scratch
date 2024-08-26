.PHONY: default check clean distclean pristine

OS_NAME := $(shell uname -s)

ifeq ($(OS_NAME), Darwin)
	.DEFAULT_GOAL := tools
else
	.DEFAULT_GOAL := tools
endif

alpine-sh:
	docker compose run --rm --build -ti lfs-alpine sh

tools:
	./lfs tools pi0

clean:
	git clean -dxf work

distclean: clean
	git clean -dxf tools install
	(! test -d /Volumes/LFS) || diskutil eject /Volumes/LFS
	rm -f lfs.sparseimage

pristine:
	rm -rf source/linux-*
	git clean -dxf

image/%.img:
	./lfs image $*

# glibc must be built in a case-sensitive filesystem
all-macos:
	test -f lfs.sparseimage || hdiutil create -size 8g -fs 'Case-sensitive APFS' -type SPARSE -volname LFS lfs
	open lfs.sparseimage
	sleep 2
	mkdir -p /Volumes/LFS/work
	WORK_DIR=/Volumes/LFS/work make default
