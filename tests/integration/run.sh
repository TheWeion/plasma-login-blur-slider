#!/bin/bash
# SPDX-FileCopyrightText: 2026 Terry Fallows <terry@weion.dev>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# run.sh [package file]
#
# Runs the integration tests. With a package file: installs it first and
# removes it again at the end, checking both. Without: expects the package to
# be installed already and leaves it installed.
#
# These tests change the system they run on; see lib.sh. Use a container or a
# virtual machine:
#
#     PLBS_ALLOW_SYSTEM_TESTS=1 tests/integration/run.sh dist/*.pkg.tar.zst

set -u

here=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
package=${1:-}
failed=()

run() {
    local name=$1
    shift
    printf '\n================ %s ================\n' "$name"
    "$@"
    case $? in
        0) ;;
        2) echo "$name: cannot run here" >&2; exit 2 ;;
        *) failed+=("$name") ;;
    esac
}

if [ -n "$package" ]; then
    run "package install" "$here/package.sh" install "$package"
fi

run "compositor" "$here/compositor.sh"
run "login screen" "$here/login-screen.sh"
run "lock screen" "$here/lock-screen.sh"

if [ -n "$package" ]; then
    run "package remove" "$here/package.sh" remove
fi

printf '\n================ summary ================\n'
if [ "${#failed[@]}" -gt 0 ]; then
    printf 'FAILED: %s\n' "${failed[*]}"
    exit 1
fi
echo "All integration tests passed."
