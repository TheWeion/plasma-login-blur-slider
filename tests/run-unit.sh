#!/bin/sh
# SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Runs the unit tests (tests/unit/*.bats).
#
# "sync" and "remove" insist on running as root. The tests only ever touch a
# throw-away directory, so for them fakeroot is root enough.

set -eu

cd -- "$(dirname -- "$0")/.."

if ! command -v bats >/dev/null 2>&1; then
    echo "bats not found. Arch: pacman -S bats; Debian/Ubuntu: apt install bats" >&2
    exit 1
fi

if [ "$(id -u)" = 0 ]; then
    exec bats "$@" tests/unit
fi

if command -v fakeroot >/dev/null 2>&1; then
    exec fakeroot -- bats "$@" tests/unit
fi

echo "fakeroot not found. Arch: pacman -S fakeroot; Debian/Ubuntu: apt install fakeroot" >&2
exit 1
