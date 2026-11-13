# Quality checks.

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
GRYPE_VERSION := 0.121.3
grype_platform := $(shell uname -s | tr A-Z a-z)_$(subst x86_64,amd64,$(subst aarch64,arm64,$(shell uname -m)))
grype_sha256_darwin_amd64 := 65bfb1b3b30d32e9dab156a60003c7146e619f649992be227bf09c9ccbf44f7e
grype_sha256_darwin_arm64 := 54336f2cd8cdee8b3d8ea83462561ff7fa9293498054c7c53a193db44bfea4c8
grype_sha256_linux_amd64 := e9da18cc1429e786722e32161288103600efffd8e483c90761f90485bd1bec85
grype_sha256_linux_arm64 := b7815598d48da78bfd16f5b98ef28e1bb09c03d34fc8c3e350f99b6ccb3c7cba
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
