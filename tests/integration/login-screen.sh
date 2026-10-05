#!/bin/bash
# SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The login screen: runs Plasma Login Manager's real wallpaper process, as the
# login user, in a headless session, with the add-on installed, and checks
# that the hook reports the configured blur and survives a blur/unblur cycle.
#
# Needs the package installed (overlays in place). Rewrites and restores
# /etc/plasmalogin.conf.

# The conditions handed to check_that are evaluated there, not here: they are
# quoted on purpose, and the variables in them do get used.
# shellcheck disable=SC2016,SC2034

# shellcheck source=tests/integration/lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
require_system_tests
need "$PROG" plasma-login-wallpaper sway dbus-run-session busctl runuser

LOGIN_USER=plasmalogin
if ! getent passwd "$LOGIN_USER" >/dev/null; then
    echo "SKIP: no $LOGIN_USER user (Plasma Login Manager not installed?)"
    exit 0
fi

CONF=/etc/plasmalogin.conf
backup=$(mktemp)
had_conf=0
if [ -f "$CONF" ]; then
    cp -p -- "$CONF" "$backup"
    had_conf=1
fi
log=$(mktemp)
chown "$LOGIN_USER" "$log"

cleanup() {
    if [ "$had_conf" = 1 ]; then
        cp -p -- "$backup" "$CONF"
    else
        rm -f -- "$CONF"
    fi
    rm -f -- "$backup" "$log"
}
trap cleanup EXIT

# run_case <intensity|default> <standard|frosted> <expected message>
run_case() {
    local intensity=$1 style=$2 expected=$3

    section "login screen: intensity $intensity, style $style"
    {
        printf '[Greeter][Wallpaper][org.kde.image][General]\n'
        [ "$intensity" = default ] || printf 'LoginBlurIntensity=%s\n' "$intensity"
        [ "$style" = standard ] || printf 'LoginBlurStyle=%s\n' "$style"
    } > "$CONF"
    chmod 644 "$CONF"

    : > "$log"
    in_headless_session "$LOGIN_USER" "$TESTS_DIR/login-wallpaper-session.sh" "$log"

    check "the hook reports: $expected" grep -qF -- "$PROG: $expected" "$log"
    check "exactly one wallpaper window was hooked" \
        test "$(grep -c "$PROG: login wallpaper blur set to" "$log")" = 1
    check "the wallpaper process survived blurring and unblurring" \
        grep -qF "plbs-test: wallpaper process still running" "$log"
    check_that "the add-on reported no problem" \
        "! grep -E '$PROG: (cannot|could not)' '$log'"
    check_that "no QML error in the add-on's files" \
        "! grep -E 'plmblur/.*(Error|is not defined|is not a type)' '$log'"

    if [ "$FAILED" -gt 0 ]; then
        echo "  --- wallpaper process log ---"
        sed 's/^/  | /' "$log" | head -n 60
    fi
}

section "the add-on is in place"
check "an overlay for the Image wallpaper exists" \
    test -f /usr/local/share/plasma/wallpapers/org.kde.image/.plasma-login-blur-slider

run_case default standard "login wallpaper blur set to 100%"
run_case 35 standard "login wallpaper blur set to 35%"
run_case 60 frosted "login wallpaper blur set to 60% (frosted glass)"
run_case 0 frosted "login wallpaper blur set to 0%"

finish
