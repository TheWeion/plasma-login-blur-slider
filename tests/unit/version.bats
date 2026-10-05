#!/usr/bin/env bats
# SPDX-License-Identifier: GPL-3.0-or-later
#
# scripts/version.sh: the version comes from the release tag, never from a
# number kept in the repository.

setup() {
    REPO=$(cd -- "$BATS_TEST_DIRNAME/../.." && pwd)
    TREE=$BATS_TEST_TMPDIR/tree
    mkdir -p "$TREE/scripts"
    cp "$REPO/scripts/version.sh" "$TREE/scripts/"
    unset PLBS_VERSION
    export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
    export GIT_AUTHOR_NAME=test GIT_AUTHOR_EMAIL=test@example.org
    export GIT_COMMITTER_NAME=test GIT_COMMITTER_EMAIL=test@example.org
}

git_tree() {
    command -v git >/dev/null || skip "git not installed"
    git -C "$TREE" init -q -b main
    git -C "$TREE" add scripts/version.sh
    git -C "$TREE" commit -q -m "feat: first"
}

commit() {
    echo "$1" >> "$TREE/file"
    git -C "$TREE" add file
    git -C "$TREE" commit -q -m "$1"
}

@test "outside of git and without a VERSION file the version is 0.0.0" {
    run "$TREE/scripts/version.sh"
    [ "$status" -eq 0 ]
    [ "$output" = 0.0.0 ]
}

@test "PLBS_VERSION overrides everything" {
    echo 1.2.3 > "$TREE/VERSION"
    PLBS_VERSION=7.8.9 run "$TREE/scripts/version.sh"
    [ "$output" = 7.8.9 ]
}

@test "a VERSION file is used as it is (release tarballs)" {
    echo 1.2.3 > "$TREE/VERSION"
    run "$TREE/scripts/version.sh"
    [ "$output" = 1.2.3 ]
}

@test "a clone without release tags counts its commits from 0.0.0" {
    git_tree
    commit "fix: second"
    run "$TREE/scripts/version.sh"
    [[ "$output" =~ ^0\.0\.0\.r2\.g[0-9a-f]{7}$ ]]
}

@test "the tagged commit has exactly the release version" {
    git_tree
    git -C "$TREE" tag v1.4.0
    run "$TREE/scripts/version.sh"
    [ "$output" = 1.4.0 ]
}

@test "commits after a release are marked as such" {
    git_tree
    git -C "$TREE" tag v1.4.0
    commit "fix: one"
    commit "fix: two"
    run "$TREE/scripts/version.sh"
    [[ "$output" =~ ^1\.4\.0\.r2\.g[0-9a-f]+$ ]]
}

@test "tags that are not releases are ignored" {
    git_tree
    git -C "$TREE" tag v2.0.0
    commit "fix: one"
    git -C "$TREE" tag nightly
    run "$TREE/scripts/version.sh"
    [[ "$output" =~ ^2\.0\.0\.r1\.g[0-9a-f]+$ ]]
}

@test "a GitHub source archive of a tag knows its version" {
    echo 'v3.1.0' > "$TREE/.git-archive-version"
    run "$TREE/scripts/version.sh"
    [ "$output" = 3.1.0 ]
    echo 'v3.1.0-5-gabc1234' > "$TREE/.git-archive-version"
    run "$TREE/scripts/version.sh"
    [ "$output" = 3.1.0.r5.gabc1234 ]
}

@test "the placeholder of a plain checkout is not mistaken for a version" {
    cp "$REPO/.git-archive-version" "$TREE/"
    run "$TREE/scripts/version.sh"
    [ "$output" = 0.0.0 ]
}

@test "the version is always a valid pacman pkgver" {
    git_tree
    git -C "$TREE" tag v1.4.0
    commit "fix: one"
    run "$TREE/scripts/version.sh"
    [[ "$output" != *-* ]]
    [[ "$output" != *:* ]]
    [[ "$output" != *" "* ]]
}
