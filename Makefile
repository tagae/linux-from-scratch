.PHONY: tools system clean docker-clean docker-distclean pristine extract qemu test

.DEFAULT_GOAL := .env

PLATFORM ?= virt

.env:
	echo PLATFORM=$(PLATFORM) > $@
	echo HOST_UID=$$(id -u) >> $@
	echo HOST_GID=$$(id -g) >> $@

tools:
	docker compose run --build --rm alpine ./lfs tools bootstrap
	docker compose run --build --rm busybox ./lfs tools build

system:
	docker compose run --build --rm alpine ./lfs system

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
	PLATFORM=$(PLATFORM) ./lfs qemu

test: extract
	./test-virt

pristine:
	git clean -dxf

docker-clean:
	docker volume rm -f linux-from-scratch_source linux-from-scratch_work linux-from-scratch_install

docker-distclean: docker-clean
	docker volume rm -f linux-from-scratch_tools
