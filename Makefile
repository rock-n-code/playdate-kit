# Development lifecycle front door for the playdate-kit package. All logic
# lives in SwiftPM, Scripts/, and the example's own Makefile; the targets
# here only dispatch. Run `make` or `make help` for the list.
#
# `build`, `test`, `docs`, and `consumer-test` need only Xcode's toolchain
# (plus the one-time `make setup`). `embedded` and the example targets
# additionally need the device toolchains described in the README.

.DEFAULT_GOAL := help

EXAMPLE_DIR := Examples/HelloPlaydate

# The embedded check needs a swift.org snapshot toolchain. Pick up the
# standard install location automatically (matching Examples/swift.mk);
# override with `make embedded SWIFT_BIN=/path/to/swift`.
SWIFT_LATEST := $(HOME)/Library/Developer/Toolchains/swift-latest.xctoolchain/usr/bin/swift
SWIFT_BIN ?= $(if $(wildcard $(SWIFT_LATEST)),$(SWIFT_LATEST),swift)

# Use Xcode's docc: swift.org toolchains ship an x86_64-only one that needs
# Rosetta. Override with `make docs DOCC_EXEC=/path/to/docc`.
DOCC_EXEC ?= $(shell TOOLCHAINS= xcrun --find docc 2>/dev/null)
DOCC_ENV := $(if $(DOCC_EXEC),DOCC_EXEC="$(DOCC_EXEC)")

.PHONY: help setup build test outdated upgrade embedded consumer-test check docs docs-preview example example-run clean

help: ## List the available targets
	@grep -E '^[a-zA-Z_-]+:.*## ' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*## "}; {printf "  %-15s %s\n", $$1, $$2}'

setup: ## One-time: point the "playdate" pkg-config module at the SDK
	Scripts/install-pkgconfig.sh

build: ## Build the bindings for the host
	swift build

test: ## Run the host-runnable unit tests
	swift test

outdated: ## Show the dependency updates that `make upgrade` would apply
	swift package update --dry-run

upgrade: ## Update the SwiftPM dependencies to their latest allowed versions
	swift package update

embedded: ## Compile-only device check (Embedded Swift, armv7em-none-none-eabi)
	SWIFT_BIN="$(SWIFT_BIN)" Scripts/build-embedded.sh

consumer-test: ## Build and run a scratch package depending on playdate-kit
	Scripts/consumer-test.sh

check: build test embedded consumer-test ## Everything CI runs: build, test, embedded, consumer-test

docs: ## Generate the DocC documentation archive
	$(DOCC_ENV) swift package generate-documentation --target PlaydateKit

docs-preview: ## Preview the DocC documentation in a local web server
	$(DOCC_ENV) swift package --disable-sandbox preview-documentation --target PlaydateKit

example: ## Build the HelloPlaydate example (device + simulator pdx)
	$(MAKE) -C $(EXAMPLE_DIR)

example-run: ## Build the example and open it in the Playdate Simulator
	$(MAKE) -C $(EXAMPLE_DIR) run

clean: ## Remove build products of the package and the example
	rm -rf .build
	$(MAKE) -C $(EXAMPLE_DIR) clean
