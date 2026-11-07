SHELL := /bin/bash
.DEFAULT_GOAL := run

BUNDLE_ID ?= com.kanta.miniplayer
SIGN_IDENTITY ?= -
PROJECT_URL ?= https://example.com/Kanta
UNIVERSAL ?= 0
INSTALL_DIR ?= /Applications
OPEN_AFTER_INSTALL ?= 1
SWIFT_FLAGS ?=

export BUNDLE_ID SIGN_IDENTITY PROJECT_URL UNIVERSAL INSTALL_DIR OPEN_AFTER_INSTALL SWIFT_FLAGS

.PHONY: build run install uninstall clean test dmg

build:
	@./scripts/bundle.sh release

run:
	@./scripts/bundle.sh debug
	@open dist/Kanta.app

install: build
	@./scripts/install.sh install

uninstall:
	@./scripts/install.sh uninstall

clean:
	@rm -rf .build dist

test:
	xcrun swift test $(SWIFT_FLAGS)

dmg: build
	@./scripts/dmg.sh
