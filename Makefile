.PHONY: tools docker-clean docker-distclean pristine

.DEFAULT_GOAL := .env

.env:
	echo HOST_UID=$$(id -u) >> $@
	echo HOST_GID=$$(id -g) >> $@

tools:
	docker compose run --build --rm bootstrap ./lfs tools bootstrap
	docker compose run --build --rm scratch ./lfs tools build

docker-clean:
	docker volume rm -f linux-from-scratch_source linux-from-scratch_work linux-from-scratch_install

docker-distclean: docker-clean
	docker volume rm -f linux-from-scratch_tools
