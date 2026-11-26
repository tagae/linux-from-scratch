.PHONY: \
	fetch \
	tools-bootstrap \
	tools \
	system %-system \
	image \
	qemu %-qemu \
	test %-test \
	invalidate \
	clean distclean pristine \
	FORCE \
	docker-tools-bootstrap \
	docker-tools \
	docker-system docker-%-system \
	docker-image \
	docker-test docker-%-test \
	docker-dev \
	docker-invalidate \
	docker-clean docker-distclean docker-pristine

# Keep all intermediate files, in particular image/*.img. Otherwise, make deletes them.
.SECONDARY:

# The `test` goal covers the whole chain for LFS_PROFILE (virt by default): tools, system, image,
# and the tests in QEMU.
.DEFAULT_GOAL := test

# Whatever depends on FORCE is out of date, as FORCE is never up to date.
FORCE:

# The release of this project that systems are made as, which the image records (os-release's
# VERSION, the SBOM): the version of the tree, from its tags and commits (bin/version). Computed here,
# as the containers have no .git. Empty outside a git checkout.
ifeq ($(origin LFS_RELEASE),undefined)
LFS_RELEASE := $(shell bin/version)
endif
export LFS_RELEASE

# User for the regular account. Defaults to the current user.
LFS_USER ?= $(USER)
export LFS_USER

# Making an image gives the system's files to root, which needs root access.
SUDO ?= sudo --preserve-env

# The system that the default targets build.
LFS_PROFILE ?= virt

# Default targets.
system: $(LFS_PROFILE)-system
image: image/$(LFS_PROFILE).img
qemu: $(LFS_PROFILE)-qemu
test: $(LFS_PROFILE)-test

# Downloads the sources of every package, for every profile.
fetch:
	for profile in $(basename $(notdir $(wildcard profile/*.sh))); do \
		LFS_PROFILE=$$profile ./lfs fetch || exit 1; \
	done

# The tools run on the build machine, whatever the system is: they are built once, and every system
# uses them, so that systems can be built at once (`make -j test pi0-pgp-test`). No profile reaches
# them, whichever system's target asks for them first.
tools-bootstrap tools: export LFS_PROFILE =

# Build a minimal native toolchain using the host's toolchain.
tools-bootstrap:
	# A native toolchain plus the temporary tools needed to build the rest.
	./lfs tools bootstrap

# Build the rest of the build tools with the bootstrapped ones.
tools: tools-bootstrap
	# Chapter 7: Building Additional Temporary Tools
	./lfs tools build

%-system image/%.img %-qemu: export LFS_PROFILE = $*

# Build the system of the profile into the system tree.
%-system: tools
	# Chapter 5: Compiling a Cross-Toolchain
	# Chapter 8: Installing Basic System Software
	# Chapter 10: Making the LFS System Bootable
	./lfs system build

# Produce a disk image from the system tree.
image/%.img: %-system FORCE
	# The image directory is the user's, rather than root's.
	mkdir -p image
	$(SUDO) ./lfs image build

# Boot the image and run the tests of its profile, profile/<profile>/test/ (see check/test).
%-test: image/%.img
	check/test $*

# Boot the image in QEMU, with an interactive serial console.
%-qemu: image/%.img
	./lfs qemu

# Deletes the archives that what has changed since the last run makes stale, uncommitted changes
# included: a recipe runs again only when its archive is gone (see bin/invalidate).
invalidate:
	bin/invalidate

# The checks have a Makefile of their own.
include check/Makefile

clean:
	rm -rf work/

distclean: clean
	rm -rf tools/

pristine: distclean
	rm -rf archive/ download/ image/

#---===[ Docker ]===---

# Default Docker targets.
docker-system: docker-$(LFS_PROFILE)-system
docker-image: docker-image/$(LFS_PROFILE).img
docker-test: docker-$(LFS_PROFILE)-test

# Environment variables picked up automatically by Docker Compose.
.env:
	@echo HOST_UID=$$(id -u) >> $@
	@echo HOST_GID=$$(id -g) >> $@

docker-%-system docker-image/%.img: export LFS_PROFILE = $*
docker-tools-bootstrap docker-tools: export LFS_PROFILE =

# The same rules through Docker Compose, up to the image.
# The bootstrap container builds the first tools,
# and the scratch container (nothing but those tools) builds the rest.
docker-tools-bootstrap: .env
	# Directories mounted by Docker Compose.
	mkdir -p download archive work/bootstrap work/boot image
	# Native toolchain plus the temporary tools needed to run the scratch container.
	docker compose run --build --rm bootstrap ./lfs tools bootstrap

docker-tools: docker-tools-bootstrap
	# Chapter 7: Building Additional Temporary Tools
	docker compose run --build --rm scratch ./lfs tools build

docker-%-system: docker-tools
	# Chapter 5: Compiling a Cross-Toolchain
	# Chapter 8: Installing Basic System Software
	# Chapter 10: Making the LFS System Bootable
	docker compose run --rm scratch ./lfs system build

docker-image/%.img: docker-%-system FORCE
	# The scratch image has no sudo (no setuid mechanism, no /etc/passwd), so build as root.
	docker compose run --rm --user 0:0 scratch ./lfs image build

# The image built through Docker runs on the host.
docker-%-test: docker-image/%.img
	check/test $*

docker-dev: .env
	docker compose run --rm --build dev

# The same, for the archives of the build through Docker Compose, whose containers are inputs too.
docker-invalidate:
	bin/invalidate --docker

# Besides the directories, these remove the volumes that Docker Compose keeps in their place.
docker-clean:
	docker volume rm -f linux-from-scratch_work

docker-distclean: docker-clean
	docker volume rm -f linux-from-scratch_tools

docker-pristine: docker-distclean
	docker compose down -v --remove-orphans
	rm -f .env
