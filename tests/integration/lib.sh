# shellcheck shell=bash
# SPDX-FileCopyrightText: 2026 Terry Fallows <terry@weion.dev>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Shared by the integration tests. Sourced, not run.
#
# These tests work on the system they run on: they install and remove the
# package, rewrite /etc/plasmalogin.conf and the login user's compositor
# settings, and create a test user. They are meant for a container or a
# virtual machine, which is why they refuse to run unless asked to.

set -u

# shellcheck disable=SC2034  # used by the tests that source this file
PROG=plasma-login-blur-slider
TESTS_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
PASSED=0
FAILED=0

require_system_tests() {
    if [ "${PLBS_ALLOW_SYSTEM_TESTS:-}" != 1 ]; then
        echo "These tests change the system they run on (package, login screen" >&2
        echo "configuration, users). Run them in a container or VM, with" >&2
        echo "PLBS_ALLOW_SYSTEM_TESTS=1 set." >&2
        exit 2
    fi
    if [ "$(id -u)" != 0 ]; then
        echo "The integration tests must be run as root." >&2
        exit 2
    fi
}

# need <command>...: skip the whole test file if something is missing.
need() {
    local tool
    for tool in "$@"; do
        if ! command -v "$tool" >/dev/null 2>&1 && [ ! -x "$tool" ]; then
            echo "SKIP: $tool not found"
            exit 0
        fi
    done
}

section() {
    printf '\n### %s\n' "$*"
}

ok() {
    printf '  PASS: %s\n' "$*"
    PASSED=$((PASSED + 1))
}

bad() {
    printf '  FAIL: %s\n' "$*"
    FAILED=$((FAILED + 1))
}

# check <description> <command>...
check() {
    local what=$1
    shift
    if "$@"; then
        ok "$what"
    else
        bad "$what"
    fi
}

# For conditions that are easier to write as a shell expression.
check_that() {
    local what=$1
    if eval "$2"; then
        ok "$what"
    else
        bad "$what"
    fi
}

finish() {
    printf '\nRESULT: %s passed, %s failed\n' "$PASSED" "$FAILED"
    [ "$FAILED" -eq 0 ]
}

# wait_for_line <file> <fixed string> <seconds>
wait_for_line() {
    local file=$1 text=$2 left=$(($3 * 2))
    while [ "$left" -gt 0 ]; do
        if [ -f "$file" ] && grep -qF -- "$text" "$file"; then
            return 0
        fi
        sleep 0.5
        left=$((left - 1))
    done
    return 1
}

# in_headless_session <user> <command>...
# Runs the command as that user inside a D-Bus session with a headless
# Wayland compositor (see headless-session.sh).
in_headless_session() {
    local user=$1 home noise status
    shift
    home=$(getent passwd "$user" | cut -d: -f6)
    # The session bus and the compositor are chatty; only show what they said
    # if the session itself failed.
    noise=$(mktemp)
    (cd / && runuser -u "$user" -- env -i HOME="$home" USER="$user" LOGNAME="$user" \
        PATH=/usr/local/bin:/usr/bin:/bin LANG=C.UTF-8 \
        dbus-run-session -- "$TESTS_DIR/headless-session.sh" "$@") > "$noise" 2>&1
    status=$?
    if [ "$status" -ne 0 ]; then
        echo "  the headless session failed (status $status):"
        sed 's/^/  | /' "$noise" | tail -n 40
    fi
    rm -f -- "$noise"
    return "$status"
}
