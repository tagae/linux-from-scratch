.PHONY: default check clean distclean pristine tools system image extract qemu test alpine-sh docker-clean docker-distclean

OS_NAME := $(shell uname -s)

.DEFAULT_GOAL := tools

PLATFORM ?= virt

tools:
	PLATFORM=$(PLATFORM) ./lfs tools

system:
	PLATFORM=$(PLATFORM) ./lfs system

image: image/$(PLATFORM).img

image/$(PLATFORM).img:
	PLATFORM=$(PLATFORM) ./lfs image image/$(PLATFORM).img

extract:
	@set -e; \
	CNAME=$$(docker run -d \
	    -v linux-from-scratch_install:/install \
	    -v linux-from-scratch_image:/image \
	    alpine sleep 10); \
	trap "docker rm -f $$CNAME >/dev/null" EXIT; \
	mkdir -p install image; \
	rm -rf install/boot; \
	docker cp $$CNAME:/install/boot install/; \
	docker cp $$CNAME:/image/$(PLATFORM).img image/

qemu:
	./lfs -p $(PLATFORM) qemu

test: extract
	./test-virt

clean:
	git clean -dxf work

distclean: clean
	git clean -dxf tools install

pristine:
	rm -rf source/linux-*
	git clean -dxf

alpine-sh:
	PLATFORM=$(PLATFORM) HOST_UID=$$(id -u) HOST_GID=$$(id -g) \
		docker compose run --build --rm alpine

docker-clean:
	docker volume rm -f linux-from-scratch_tools linux-from-scratch_work linux-from-scratch_install linux-from-scratch_image

docker-distclean: docker-clean
	docker volume rm -f linux-from-scratch_source linux-from-scratch_download

# macOS: glibc requires a case-sensitive filesystem
all-macos:
	test -f lfs.sparseimage || hdiutil create -size 16g -fs 'Case-sensitive APFS' -type SPARSE -volname LFS lfs
	open lfs.sparseimage
	sleep 2
	mkdir -p /Volumes/LFS/work
	WORK_DIR=/Volumes/LFS/work make system
