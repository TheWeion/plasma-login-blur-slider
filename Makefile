# SPDX-License-Identifier: GPL-3.0-or-later

NAME    := plasma-login-blur-slider
# The systemd user unit that starts the login screen's compositor.
KWINUNIT := plasma-login-kwin_wayland.service
VERSION := 1.0.0

PREFIX  ?= /usr
BINDIR  ?= $(PREFIX)/bin
DATADIR ?= $(PREFIX)/share/$(NAME)
DOCDIR  ?= $(PREFIX)/share/doc/$(NAME)
UNITDIR ?= $(PREFIX)/lib/systemd/system
USERUNITDIR ?= $(PREFIX)/lib/systemd/user
HOOKDIR ?= $(PREFIX)/share/libalpm/hooks

.PHONY: all install install-alpm-hook install-systemd-unit uninstall dist

all:
	@echo "Nothing to build. See README.md for how to install."

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

dist:
	tmp=$$(mktemp -d) && \
	tar --transform 's|^\.|$(NAME)-$(VERSION)|' --exclude='./*.tar.gz' --exclude='./*.pkg.tar.*' --exclude='./pkg' --exclude='./src' \
	    --owner=0 --group=0 -czf "$$tmp/$(NAME)-$(VERSION).tar.gz" ./ && \
	mv "$$tmp/$(NAME)-$(VERSION).tar.gz" . && rmdir "$$tmp"
