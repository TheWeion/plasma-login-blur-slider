#!/bin/sh
# SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# install-dev-deps.sh [lint|build|test|release]...
#
# Installs what development needs, on an Arch-based system (run as root).
# Without arguments: everything. The CI workflows use this too, so that there
# is one list.
#
#   lint     shellcheck, actionlint, qmllint and the QML modules it resolves
#   build    makepkg and friends, namcap
#   test     bats; and for the integration tests Plasma Login Manager, the
#            lock screen and a headless compositor with software rendering
#   release  Node.js for semantic-release and commitlint

set -eu

if ! command -v pacman >/dev/null 2>&1; then
    echo "This script is for Arch-based systems (pacman). Elsewhere, install the" >&2
    echo "equivalents of: shellcheck bats fakeroot git make, and Node.js for the" >&2
    echo "release tooling. Building the package and the integration tests need Arch." >&2
    exit 1
fi

[ "$#" -gt 0 ] || set -- lint build test release

packages="git make"
for group in "$@"; do
    case "$group" in
        lint)
            packages="$packages shellcheck actionlint qt6-declarative kirigami kcmutils qt6-5compat plasma-workspace"
            ;;
        build)
            packages="$packages base-devel namcap"
            ;;
        test)
            packages="$packages bats fakeroot kconfig plasma-workspace plasma-login-manager kscreenlocker sway mesa dbus libxml2"
            ;;
        release)
            packages="$packages nodejs npm"
            ;;
        *)
            echo "unknown group: $group (lint, build, test, release)" >&2
            exit 2
            ;;
    esac
done

# -Syu: on a rolling distribution, installing without upgrading can leave
# libraries out of step.
# shellcheck disable=SC2086
exec pacman -Syu --noconfirm --needed $packages
