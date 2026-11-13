# Checks of the code, and of the images and their SBOMs. The checks of the images need tools that no
# build does: they come from PyPI and GitHub into work/check/, and need a network. The Makefile
# includes this one, so that `make lint` works from the repository root, and so does
# `make -f check/Makefile lint`. The paths are those of the repository root.

.PHONY: lint sbom-check vulnerability-check

# Static checks that need no build: shell code, recipes and profiles (needs dash and shellcheck).
lint:
	check/lint

# Validates the SBOMs under image/ against the SPDX 2.3 model.
SPDX_TOOLS_VERSION := 0.8.5
pyspdxtools := work/check/spdx-tools-$(SPDX_TOOLS_VERSION)/bin/pyspdxtools

$(pyspdxtools):
	python3 -m venv $(abspath $(dir $@)..)
	$(dir $@)pip install --quiet --disable-pip-version-check spdx-tools==$(SPDX_TOOLS_VERSION)

sbom-check: $(pyspdxtools)
	@set -- image/*.spdx.json; \
	[ -e "$$1" ] || { echo "No SBOM under image/: make an image" >&2; exit 1; }; \
	for sbom; do echo "$$sbom"; $(pyspdxtools) --infile "$$sbom" || exit 1; done

# Scans the SBOMs under image/ for vulnerabilities with Grype.
GRYPE_VERSION := 0.121.0
grype_platform := $(shell uname -s | tr A-Z a-z)_$(subst x86_64,amd64,$(subst aarch64,arm64,$(shell uname -m)))
grype_sha256_darwin_amd64 := 27eef17e42f0340af6582cdbc33ad18faf9f601c613ab81d2e1658a94cbc357f
grype_sha256_darwin_arm64 := 7be39d3a0428c664ce0183e4aba31ed9accffce9eda7e7f6fa84e9c512285f27
grype_sha256_linux_amd64 := 64e07133d3486115de647a66581461dccf5c732748a0a3119077395565f15519
grype_sha256_linux_arm64 := 86f570f75ca947ea3dd6486309232bcff6d78e44ba081ae75ab14eab72be3dae
grype := work/check/grype-$(GRYPE_VERSION)/grype

$(grype):
	@[ -n "$(grype_sha256_$(grype_platform))" ] \
		|| { echo "No Grype $(GRYPE_VERSION) for $(grype_platform)" >&2; exit 1; }
	mkdir -p $(dir $@)
	curl -sSfLo $(dir $@)grype.tar.gz https://github.com/anchore/grype/releases/download/v$(GRYPE_VERSION)/grype_$(GRYPE_VERSION)_$(grype_platform).tar.gz
	echo "$(grype_sha256_$(grype_platform))  $(dir $@)grype.tar.gz" | shasum -a 256 -c
	tar -xzf $(dir $@)grype.tar.gz -C $(dir $@) grype
	rm $(dir $@)grype.tar.gz

vulnerability-check: $(grype)
	check/vulnerabilities $(grype)
