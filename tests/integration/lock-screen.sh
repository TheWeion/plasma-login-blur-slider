#!/bin/bash
# SPDX-FileCopyrightText: 2026 Terry Fallows <terry@weion.dev>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The lock screen: runs the real lock screen in its test mode, as an ordinary
# user created for the purpose, in a headless session, and checks that the
# hook picks up that user's lock screen settings (set with "--lock").
#
# Needs the package installed (overlays in place).

# The conditions handed to check_that are evaluated there, not here: they are
# quoted on purpose, and the variables in them do get used.
# shellcheck disable=SC2016,SC2034

# shellcheck source=tests/integration/lib.sh
. "$(dirname -- "${BASH_SOURCE[0]}")/lib.sh"
require_system_tests
need "$PROG" sway dbus-run-session runuser useradd kwriteconfig6

greeter=""
for candidate in /usr/lib/kscreenlocker_greet /usr/libexec/kscreenlocker_greet \
    /usr/lib/*/libexec/kscreenlocker_greet /usr/lib64/libexec/kscreenlocker_greet; do
    if [ -x "$candidate" ]; then
        greeter=$candidate
        break
    fi
done
if [ -z "$greeter" ]; then
    echo "SKIP: kscreenlocker_greet not found"
    exit 0
fi

TEST_USER=plbs-test
created=0
if ! getent passwd "$TEST_USER" >/dev/null; then
    useradd --create-home "$TEST_USER"
    created=1
fi
user_home=$(getent passwd "$TEST_USER" | cut -d: -f6)
log=$(mktemp)
chown "$TEST_USER" "$log"

cleanup() {
    rm -f -- "$log"
    if [ "$created" = 1 ]; then
        userdel --remove "$TEST_USER" >/dev/null 2>&1
    fi
}
trap cleanup EXIT

as_user() {
    (cd / && runuser -u "$TEST_USER" -- env -i HOME="$user_home" USER="$TEST_USER" \
        PATH=/usr/local/bin:/usr/bin:/bin LANG=C.UTF-8 "$@")
}

# run_case <intensity> <standard|frosted> <expected message>
run_case() {
    local intensity=$1 style=$2 expected=$3

    section "lock screen: intensity $intensity, style $style"
    as_user "$PROG" set "$intensity" --lock --quiet
    as_user "$PROG" style "$style" --lock --quiet
    check "the settings read back" \
        test "$(as_user "$PROG" get --lock) $(as_user "$PROG" style --lock)" = "$intensity $style"

    : > "$log"
    in_headless_session "$TEST_USER" "$TESTS_DIR/lock-screen-session.sh" "$greeter" "$log"

    check "the hook reports: $expected" grep -qF -- "$PROG: $expected" "$log"
    check "the lock screen kept running" grep -qF "plbs-test: lock screen still running" "$log"
    check_that "the add-on reported no problem" \
        "! grep -E '$PROG: (cannot|could not)' '$log'"
    check_that "no QML error in the add-on's files" \
        "! grep -E 'plmblur/.*(Error|is not defined|is not a type)' '$log'"

    if [ "$FAILED" -gt 0 ]; then
        echo "  --- lock screen log ---"
        sed 's/^/  | /' "$log" | head -n 60
    fi
}

section "the add-on is in place"
check "an overlay for the Image wallpaper exists" \
    test -f /usr/local/share/plasma/wallpapers/org.kde.image/.plasma-login-blur-slider

run_case 100 standard "lock screen wallpaper blur set to 100%"
run_case 40 standard "lock screen wallpaper blur set to 40%"
run_case 55 frosted "lock screen wallpaper blur set to 55% (frosted glass)"

section "the login screen's settings were not touched"
check_that "no lock screen value ended up in /etc/plasmalogin.conf" \
    "! grep -q 'LoginBlurIntensity=55' /etc/plasmalogin.conf 2>/dev/null"

finish
