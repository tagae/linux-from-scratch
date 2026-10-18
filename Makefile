.PHONY: \
	tools %-tools \
	system %-system \
	image \
	qemu %-qemu \
	test %-test \
	clean distclean pristine \
	FORCE \
	docker-tools docker-%-tools \
	docker-system docker-%-system \
	docker-image \
	docker-clean docker-distclean docker-pristine

# Keep all intermediate files, in particular image/*.img. Otherwise, make deletes them.
.SECONDARY:

# The `test` goal covers the whole chain for the `virt` platform: tools, system, image, and
# emulation.
.DEFAULT_GOAL := test

# Whatever depends on FORCE will be considered out of date, since it depends on nothing.
FORCE:

# The release for built systems.
export LFS_RELEASE ?= r13.0-143

# Making an image opens loop devices and mounts file systems, which needs root access.
SUDO ?= sudo --preserve-env

# Default targets.
tools: virt-systemd-gnu-tools
system: virt-systemd-gnu-system
image: image/virt-systemd-gnu.img
qemu: virt-systemd-gnu-qemu
test: virt-systemd-gnu-test

%-tools %-system image/%.img %-qemu: export SYSTEM_KEY = $*

# Build tools.
%-tools:
	# A native toolchain plus the temporary tools needed to build the rest.
	./lfs tools bootstrap
	# Chapter 7: Building Additional Temporary Tools
	./lfs tools build

%-system: %-tools
	# Chapter 5: Compiling a Cross-Toolchain
	# Chapter 8: Installing Basic System Software
	# Chapter 10: Making the LFS System Bootable
	./lfs system build

image/%.img: %-system FORCE
	# The image directory is the user's, rather than root's.
	mkdir -p image
	$(SUDO) ./lfs image build
	# The image is root's, but QEMU opens it for writing as the user.
	$(SUDO) chown $$(id -u):$$(id -g) $@

%-test: image/%.img
	./test $*

%-qemu: image/%.img
	./lfs qemu

clean:
	rm -rf source/ work/ install/

distclean: clean
	rm -rf tools/

pristine: distclean
	rm -rf archive/ download/ image/

#---===[ Docker ]===---

# Default Docker targets.
docker-tools: docker-virt-systemd-gnu-tools
docker-system: docker-virt-systemd-gnu-system
docker-image: docker-image/virt-systemd-gnu.img

# Environment variables picked up automatically by Docker Compose.
.env:
	@echo HOST_UID=$$(id -u) >> $@
	@echo HOST_GID=$$(id -g) >> $@
	@echo LFS_RELEASE=$(LFS_RELEASE) >> $@

docker-%-tools docker-%-system docker-image/%.img: export SYSTEM_KEY = $*

# The same rules through Docker Compose, up to the image.
# The bootstrap container builds the first tools,
# and the scratch container (nothing but those tools) builds the rest.
docker-%-tools: .env
	# A native toolchain plus the temporary tools needed to run the scratch container.
	docker compose run --build --rm bootstrap ./lfs tools bootstrap
	# Chapter 7: Building Additional Temporary Tools
	docker compose run --build --rm scratch ./lfs tools build

docker-%-system: docker-%-tools
	# Chapter 5: Compiling a Cross-Toolchain
	# Chapter 8: Installing Basic System Software
	# Chapter 10: Making the LFS System Bootable
	docker compose run --rm scratch ./lfs system build

docker-image/%.img: docker-%-system FORCE
	# The scratch image has no sudo (no setuid mechanism, no /etc/passwd), so build as root.
	docker compose run --rm --user 0:0 scratch ./lfs image build

# Besides the directories, these remove the volumes that Docker Compose keeps in their place.
docker-clean: clean
	docker volume rm -f linux-from-scratch_source linux-from-scratch_work linux-from-scratch_install

docker-distclean: docker-clean distclean
	docker volume rm -f linux-from-scratch_tools

docker-pristine: docker-distclean pristine
	rm -rf .env
	docker compose down -v
