.PHONY: \
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
	docker-invalidate \
	docker-clean docker-distclean docker-pristine

# Keep all intermediate files, in particular image/*.img. Otherwise, make deletes them.
.SECONDARY:

# The `test` goal covers the whole chain for the `virt` platform: tools, system, image, and
# emulation.
.DEFAULT_GOAL := test

# Whatever depends on FORCE will be considered out of date, since it depends on nothing.
FORCE:

# The release of this project that systems are made as, which the image records (os-release's
# VERSION, the SBOM): the version of the tree, from its tags and commits (bin/version). Computed here,
# as the containers have no .git. Empty outside a git checkout.
ifeq ($(origin LFS_RELEASE),undefined)
LFS_RELEASE := $(shell bin/version 2>/dev/null)
endif
export LFS_RELEASE

# Making an image gives the system's files to root, which needs root access.
SUDO ?= sudo --preserve-env

# The system that the default targets build: a profile, profile/<profile>.sh, whose name is the key
# of everything that is made for it.
PROFILE ?= virt

# Default targets.
system: $(PROFILE)-system
image: image/$(PROFILE).img
qemu: $(PROFILE)-qemu
test: $(PROFILE)-test

%-system image/%.img %-qemu: export PROFILE = $*

# The tools run on the build machine, whatever the system is: they are built once, and every system
# uses them, so that systems can be built at once (`make -j test pi0-pgp-test`). No profile reaches
# them, whichever system's target asks for them first.
tools-bootstrap tools: export PROFILE =

# Build tools.
tools-bootstrap:
	# A native toolchain plus the temporary tools needed to build the rest.
	./lfs tools bootstrap

tools: tools-bootstrap
	# Chapter 7: Building Additional Temporary Tools
	./lfs tools build

%-system: tools
	# Chapter 5: Compiling a Cross-Toolchain
	# Chapter 8: Installing Basic System Software
	# Chapter 10: Making the LFS System Bootable
	./lfs system build
	./lfs check

image/%.img: %-system FORCE
	# The image directory is the user's, rather than root's.
	mkdir -p image
	$(SUDO) ./lfs image build

%-test: image/%.img
	check/boot $*

%-qemu: image/%.img
	./lfs qemu

# Deletes the archives that what has changed since the last run makes stale, uncommitted changes
# included: a recipe runs again only when its archive is gone (see bin/invalidate).
invalidate:
	bin/invalidate

# The checks have a Makefile of their own.
include check/Makefile

clean:
	rm -rf source/ work/ install/

distclean: clean
	rm -rf tools/

pristine: distclean
	rm -rf archive/ download/ image/

#---===[ Docker ]===---

# Default Docker targets.
docker-system: docker-$(PROFILE)-system
docker-image: docker-image/$(PROFILE).img
docker-test: docker-$(PROFILE)-test

# Environment variables picked up automatically by Docker Compose.
.env:
	@echo HOST_UID=$$(id -u) >> $@
	@echo HOST_GID=$$(id -g) >> $@

docker-%-system docker-image/%.img: export PROFILE = $*
docker-tools-bootstrap docker-tools: export PROFILE =

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
	docker compose run --rm scratch ./lfs check

docker-image/%.img: docker-%-system FORCE
	# The scratch image has no sudo (no setuid mechanism, no /etc/passwd), so build as root.
	docker compose run --rm --user 0:0 scratch ./lfs image build

# The image built through Docker runs on the host.
docker-%-test: docker-image/%.img
	check/boot $*

# The same, for the archives of the build through Docker Compose, whose containers are inputs too.
docker-invalidate:
	bin/invalidate --docker

# Besides the directories, these remove the volumes that Docker Compose keeps in their place.
docker-clean: clean
	docker volume rm -f linux-from-scratch_source linux-from-scratch_work linux-from-scratch_install

docker-distclean: docker-clean distclean
	docker volume rm -f linux-from-scratch_tools

docker-pristine: docker-distclean pristine
	docker compose down -v --remove-orphans
	rm -f .env
