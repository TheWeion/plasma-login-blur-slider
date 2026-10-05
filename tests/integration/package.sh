#!/bin/bash
# SPDX-FileCopyrightText: 2026 Terry Fallows <terry@weion.dev>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# package.sh install <package file>
# package.sh remove
#
# The pacman side: installing the package sets everything up, removing it
# leaves nothing behind.

# The conditions handed to check_that are evaluated there, not here: they are
# quoted on purpose, and the variables in them do get used.
# shellcheck disable=SC2016,SC2034

# shellcheck source=tests/integration/lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
require_system_tests
need pacman

OVERLAYS=/usr/local/share/plasma/wallpapers
STOCK=/usr/share/plasma/wallpapers
DROPIN=/usr/lib/systemd/user/plasma-login-kwin_wayland.service.d/50-$PROG.conf
HOOK=/usr/share/libalpm/hooks/$PROG.hook

our_overlays() {
    find "$OVERLAYS" -mindepth 2 -maxdepth 2 -name ".$PROG" 2>/dev/null | wc -l
}

case "${1:-}" in
    install)
        package=${2:?package.sh install <package file>}
        section "installing $(basename "$package")"
        check "pacman installs it" pacman -U --noconfirm "$package"
        qkk=$(pacman -Qkk "$PROG" 2>&1)
        check_that "every installed file is as packaged" \
            'grep -q ", 0 altered files" <<< "$qkk"'
        if ! grep -q ", 0 altered files" <<< "$qkk"; then
            printf '%s\n' "$qkk" | sed 's/^/  | /'
        fi
        check_that "the tool reports the package's version" \
            '[ "$PROG $(pacman -Q "$PROG" | sed "s/.* //; s/-[0-9]*$//")" = "$("$PROG" --version)" ]'
        check "the pacman hook is installed" test -f "$HOOK"
        check "the compositor drop-in is installed" test -f "$DROPIN"
        if [ -d "$STOCK/org.kde.image" ]; then
            check "the Image wallpaper has an overlay" test -f "$OVERLAYS/org.kde.image/.$PROG"
            check_that "the stock Image wallpaper was not touched" \
                '[ -f "$STOCK/org.kde.image/contents/ui/main.qml" ] && [ ! -e "$STOCK/org.kde.image/.$PROG" ]'
        fi
        check_that "status runs and lists the overlays" '"$PROG" status | grep -q "overlay active"'
        ;;
    remove)
        section "removing the package"
        check "pacman removes it" pacman -R --noconfirm "$PROG"
        check_that "no overlay is left" '[ "$(our_overlays)" = 0 ]'
        check_that "the tool and its data are gone" \
            '[ ! -e "/usr/bin/$PROG" ] && [ ! -e "/usr/share/$PROG" ]'
        check_that "the hook and the drop-in are gone" \
            '[ ! -e "$HOOK" ] && [ ! -e "$DROPIN" ] && [ ! -e "$(dirname "$DROPIN")" ]'
        if [ -d "$STOCK/org.kde.image" ]; then
            check "the stock Image wallpaper is still there" test -f "$STOCK/org.kde.image/contents/ui/main.qml"
        fi
        ;;
    *)
        echo "usage: package.sh install <package file> | package.sh remove" >&2
        exit 2
        ;;
esac

finish
