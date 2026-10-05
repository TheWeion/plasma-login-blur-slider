# SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors
# SPDX-License-Identifier: GPL-3.0-or-later

NAME    := plasma-login-blur-slider
# The systemd user unit that starts the login screen's compositor.
KWINUNIT := plasma-login-kwin_wayland.service
# Not kept here: releases are git tags, and scripts/version.sh derives the
# version from them (or from the VERSION file of a release tarball).
ifeq ($(origin VERSION),undefined)
VERSION := $(shell ./scripts/version.sh)
endif

PREFIX  ?= /usr
BINDIR  ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share/$(NAME)
DOCDIR  ?= $(PREFIX)/share/doc/$(NAME)
UNITDIR ?= $(PREFIX)/lib/systemd/system
USERUNITDIR ?= $(PREFIX)/lib/systemd/user
HOOKDIR ?= $(PREFIX)/share/libalpm/hooks

.PHONY: all install install-alpm-hook install-systemd-unit uninstall \
        dist package lint lint-sh lint-qml lint-workflows lint-reuse \
        test test-integration check release-preview clean

all:
	@echo "Nothing to build. See README.md for how to install, CONTRIBUTING.md for development."

# The files every installation needs. Afterwards run "$(NAME) sync" as root.
install:
	install -d "$(DESTDIR)$(BINDIR)" "$(DESTDIR)$(DATADIR)/qml" "$(DESTDIR)$(DATADIR)/wrappers" "$(DESTDIR)$(DOCDIR)"
	sed -e 's|@VERSION@|$(VERSION)|g' -e 's|@DATADIR@|$(DATADIR)|g' $(NAME).in > "$(DESTDIR)$(BINDIR)/$(NAME)"
	chmod 755 "$(DESTDIR)$(BINDIR)/$(NAME)"
	install -m644 qml/*.qml "$(DESTDIR)$(DATADIR)/qml/"
	install -m644 wrappers/*.qml "$(DESTDIR)$(DATADIR)/wrappers/"
	install -m644 README.md "$(DESTDIR)$(DOCDIR)/"
	install -d "$(DESTDIR)$(USERUNITDIR)/$(KWINUNIT).d"
	sed -e 's|@BINDIR@|$(BINDIR)|g' packaging/login-compositor.conf.in > "$(DESTDIR)$(USERUNITDIR)/$(KWINUNIT).d/50-$(NAME).conf"
	chmod 644 "$(DESTDIR)$(USERUNITDIR)/$(KWINUNIT).d/50-$(NAME).conf"

# Arch-based distributions: refresh the overlays whenever pacman touches a
# wallpaper plugin.
install-alpm-hook:
	install -d "$(DESTDIR)$(HOOKDIR)"
	install -m644 packaging/$(NAME).hook "$(DESTDIR)$(HOOKDIR)/"

# Other distributions: refresh the overlays at every boot instead
# (systemctl enable --now $(NAME).service).
install-systemd-unit:
	install -d "$(DESTDIR)$(UNITDIR)"
	sed -e 's|@BINDIR@|$(BINDIR)|g' packaging/$(NAME).service.in > "$(DESTDIR)$(UNITDIR)/$(NAME).service"
	chmod 644 "$(DESTDIR)$(UNITDIR)/$(NAME).service"

uninstall:
	-[ -n "$(DESTDIR)" ] || "$(BINDIR)/$(NAME)" remove
	rm -f "$(DESTDIR)$(BINDIR)/$(NAME)"
	rm -rf "$(DESTDIR)$(DATADIR)" "$(DESTDIR)$(DOCDIR)"
	rm -f "$(DESTDIR)$(HOOKDIR)/$(NAME).hook" "$(DESTDIR)$(UNITDIR)/$(NAME).service"
	rm -f "$(DESTDIR)$(USERUNITDIR)/$(KWINUNIT).d/50-$(NAME).conf"
	-rmdir "$(DESTDIR)$(USERUNITDIR)/$(KWINUNIT).d" 2>/dev/null

# --- development --------------------------------------------------------------

# The source tarball, in dist/.
dist:
	./scripts/dist.sh

# The source tarball and the Arch package, in dist/ (needs makepkg).
package:
	./scripts/dist.sh --package

lint: lint-sh lint-qml lint-workflows lint-reuse

# The tool is a template; lint what gets installed.
lint-sh:
	@tmp=$$(mktemp) && \
	sed -e 's|@VERSION@|$(VERSION)|g' -e 's|@DATADIR@|$(DATADIR)|g' $(NAME).in > "$$tmp" && \
	bash -n "$$tmp" && shellcheck --shell=bash "$$tmp"; status=$$?; rm -f "$$tmp"; exit $$status
	shellcheck -x scripts/*.sh tests/run-unit.sh tests/integration/*.sh
	shellcheck --shell=bash tests/unit/helpers.bash
	@echo "shell: no warnings"

lint-qml:
	./scripts/lint-qml.sh

lint-workflows:
	actionlint .github/workflows/*.yml
	@echo "workflows: no warnings"

# Every file states its copyright and its licence (https://reuse.software),
# and LICENSE, where people and GitHub look, is the same text as the copy in
# LICENSES/, where the REUSE tool looks.
lint-reuse:
	reuse lint --lines
	cmp LICENSE LICENSES/GPL-3.0-or-later.txt
	@echo "licensing: every file accounted for"

# Unit tests: the tool against a throw-away directory tree. Safe anywhere.
test:
	./tests/run-unit.sh

# Integration tests: the installed package against the real login screen and
# lock screen. They change the system they run on: containers and VMs only.
test-integration:
	./tests/integration/run.sh $(PACKAGE)

check: lint test

# What the release workflow would do with the commits since the last release
# (needs "npm ci").
release-preview:
	@node scripts/release-preview.mjs

clean:
	rm -rf dist
