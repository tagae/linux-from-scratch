.PHONY: tools docker-clean docker-distclean pristine

system: tools
	docker compose run --rm scratch ./lfs system build

tools: .env
	# Chapter 5: Compiling a Cross-Toolchain
	# Chapter 6: Cross Compiling Temporary Tools
	docker compose run --build --rm bootstrap ./lfs tools bootstrap
	# Chapter 7: Building Additional Temporary Tools
	docker compose run --build --rm scratch ./lfs tools build

.env:
	echo HOST_UID=$$(id -u) >> $@
	echo HOST_GID=$$(id -g) >> $@

clean:
	docker volume rm -f linux-from-scratch_source linux-from-scratch_work linux-from-scratch_install

distclean:
	docker compose down -v
	rm -r work/
