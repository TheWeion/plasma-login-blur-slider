#!/bin/bash
# SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# dist.sh [--package]
#
# Builds the release files into dist/:
#
#   plasma-login-blur-slider-<version>.tar.gz             the source, with a VERSION file
#   plasma-login-blur-slider-<version>-1-any.pkg.tar.zst  with --package; needs makepkg,
#                                                         that is an Arch-based system
#   SHA256SUMS
#
# The version comes from scripts/version.sh. Everything is built in a
# temporary copy, so the working tree (PKGBUILD included) is left as it is.

set -euo pipefail

name=plasma-login-blur-slider
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
want_package=0
case "${1:-}" in
    --package) want_package=1 ;;
    '') ;;
    *)
        echo "usage: dist.sh [--package]" >&2
        exit 2
        ;;
esac

version=$("$root/scripts/version.sh")
out=$root/dist
work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT
stage=$work/$name-$version
mkdir -p -- "$stage" "$out"

# The source is the files git tracks, as they are in the working tree; or,
# outside of a clone, everything but build output. Files git does not track
# stay out, so that nothing that merely happens to lie around ends up in a
# release.
if git -C "$root" rev-parse --git-dir >/dev/null 2>&1; then
    while IFS= read -r -d '' file; do
        if [ -e "$root/$file" ]; then
            (cd -- "$root" && cp --parents -- "$file" "$stage")
        fi
    done < <(git -C "$root" ls-files -z --cached)
    left_out=$(git -C "$root" ls-files --others --exclude-standard)
    if [ -n "$left_out" ]; then
        echo "Left out, because git does not track them (\"git add\" them to include them):"
        printf '%s\n' "$left_out" | head -n 10 | sed 's/^/  /'
    fi
else
    (cd -- "$root" && tar -cf - \
        --exclude=./dist --exclude=./node_modules --exclude=./pkg --exclude=./src \
        --exclude='./*.pkg.tar.*' --exclude='./*.tar.gz' --exclude=./.git .) \
        | tar -xf - -C "$stage"
fi

printf '%s\n' "$version" > "$stage/VERSION"
sed -i "s/^pkgver=.*/pkgver=$version/" "$stage/PKGBUILD"

rm -f -- "$out/$name-"*.tar.gz "$out/$name-"*.pkg.tar.* "$out/SHA256SUMS"
tar -C "$work" --owner=0 --group=0 --numeric-owner --sort=name \
    -czf "$out/$name-$version.tar.gz" "$name-$version"

if [ "$want_package" = 1 ]; then
    if ! command -v makepkg >/dev/null 2>&1; then
        echo "makepkg not found: the package can only be built on an Arch-based system" >&2
        exit 1
    fi
    mkdir -p -- "$work/pkgdest"
    # -d: the package has no build-time needs, so do not insist on Plasma
    # being installed just to pack a few text files.
    if [ "$(id -u)" = 0 ]; then
        # makepkg refuses to run as root.
        builder=${BUILD_USER:-nobody}
        chown -R -- "$builder" "$work"
        (cd -- "$stage" && runuser -u "$builder" -- env HOME="$work" PKGDEST="$work/pkgdest" \
            PKGEXT=.pkg.tar.zst makepkg -f -d)
    else
        (cd -- "$stage" && PKGDEST="$work/pkgdest" PKGEXT=.pkg.tar.zst makepkg -f -d)
    fi
    cp -- "$work"/pkgdest/*.pkg.tar.zst "$out/"
fi

(cd -- "$out" && sha256sum -- "$name-"* > SHA256SUMS)

echo "Built in $out:"
for file in "$out"/*; do
    echo "  ${file##*/}"
done
