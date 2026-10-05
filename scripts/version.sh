#!/bin/sh
# SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Prints the version of this source tree. Nothing in the repository carries a
# version number: releases are git tags (vX.Y.Z) made by the release workflow,
# and everything else is derived from them here.
#
#   1. $PLBS_VERSION, when set          the release workflow, or an override
#   2. the file VERSION                 release tarballs carry one
#   3. the file .git-archive-version    GitHub's "Source code" archives of a tag
#   4. git describe                     a clone:  v1.2.3            -> 1.2.3
#                                                 v1.2.3-4-gabc1234 -> 1.2.3.r4.gabc1234
#   5. 0.0.0                            none of the above
#
# The result is always a valid pacman pkgver (no hyphens).

set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

# "v1.2.3-4-gabc1234" (git describe --long) or "v1.2.3" -> pkgver style
from_describe() {
    d=${1#v}
    case "$d" in
        *-*-g*)
            base=${d%-*-g*}
            rest=${d#"$base"-}
            count=${rest%%-*}
            hash=${rest#*-}
            if [ "$count" = 0 ]; then
                printf '%s\n' "$base"
            else
                printf '%s.r%s.%s\n' "$base" "$count" "$hash"
            fi
            ;;
        *)
            printf '%s\n' "$d"
            ;;
    esac
}

if [ -n "${PLBS_VERSION:-}" ]; then
    printf '%s\n' "$PLBS_VERSION"
    exit 0
fi

if [ -s "$root/VERSION" ]; then
    head -n 1 "$root/VERSION"
    exit 0
fi

if [ -f "$root/.git-archive-version" ]; then
    archived=$(head -n 1 "$root/.git-archive-version")
    case "$archived" in
        v[0-9]*)
            from_describe "$archived"
            exit 0
            ;;
    esac
fi

if command -v git >/dev/null 2>&1 && git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    if described=$(git -C "$root" describe --tags --long --match 'v[0-9]*' 2>/dev/null); then
        from_describe "$described"
        exit 0
    fi
    # No release tag yet.
    if count=$(git -C "$root" rev-list --count HEAD 2>/dev/null); then
        printf '0.0.0.r%s.g%s\n' "$count" "$(git -C "$root" rev-parse --short=7 HEAD)"
        exit 0
    fi
fi

printf '0.0.0\n'
