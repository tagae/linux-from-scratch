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

# Environment variables picked up automatically by Docker Compose.
.env:
	@echo HOST_UID=$$(id -u) >> $@
	@echo HOST_GID=$$(id -g) >> $@
	@echo LFS_RELEASE=r13.0-143 >> $@

# Default targets.
tools: virt-systemd-gnu-tools
system: virt-systemd-gnu-system
image: image/virt-systemd-gnu.img
qemu: virt-systemd-gnu-qemu
test: virt-systemd-gnu-test

%-tools %-system image/%.img %-qemu: export SYSTEM_KEY = $*

# Toolchain.
%-tools: .env
	# Chapter 5: Compiling a Cross-Toolchain
	# Chapter 6: Cross Compiling Temporary Tools
	docker compose run --build --rm bootstrap ./lfs tools bootstrap
	# Chapter 7: Building Additional Temporary Tools
	docker compose run --build --rm scratch ./lfs tools build

%-system: %-tools
	# Chapter 8: Installing Basic System Software
	# Chapter 9: System Configuration
	docker compose run --rm scratch ./lfs system build

image/%.img: %-system FORCE
	# The scratch image has no sudo (no setuid mechanism, no /etc/passwd), so build as root.
	docker compose run --rm --user 0:0 scratch ./lfs image build

%-test: image/%.img
	./test $*

%-qemu: image/%.img
	./lfs qemu

clean:
	rm -rf source/ work/ install/
	docker volume rm -f linux-from-scratch_source linux-from-scratch_work linux-from-scratch_install

distclean: clean
	rm -rf tools/
	docker volume rm -f linux-from-scratch_tools

pristine: distclean
	rm -rf .env archive/ download/ image/
	docker compose down -v
