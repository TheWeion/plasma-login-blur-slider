#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Terry Fallows <terry@weion.dev>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# sync and remove: creating, refreshing and deleting the wallpaper overlays.

load helpers

setup() {
    common_setup
    standard_plugins
}

@test "sync overlays the installed plugins on its list, and only those" {
    run "$TOOL" sync
    [ "$status" -eq 0 ]
    [ -f "$OVERLAY/org.kde.image/.plasma-login-blur-slider" ]
    [ -f "$OVERLAY/org.kde.color/.plasma-login-blur-slider" ]
    [ -f "$OVERLAY/org.kde.haenau/.plasma-login-blur-slider" ]
    [ ! -e "$OVERLAY/org.example.other" ]
    # on the list, but not installed
    [ ! -e "$OVERLAY/org.kde.potd" ]
}

@test "an overlay keeps the plugin's metadata and records where it came from" {
    "$TOOL" sync --quiet
    cmp "$STOCK/org.kde.image/metadata.json" "$OVERLAY/org.kde.image/metadata.json"
    grep -qx "source=$STOCK/org.kde.image" "$OVERLAY/org.kde.image/.plasma-login-blur-slider"
}

@test "an overlay reaches the stock QML through a relative path" {
    "$TOOL" sync --quiet
    local qmldir=$OVERLAY/org.kde.image/contents/ui/stock/qmldir
    local main config
    main=$(awk '$1 == "StockMain" { print $3 }' "$qmldir")
    config=$(awk '$1 == "StockConfig" { print $3 }' "$qmldir")
    # relative, as qmldir requires
    [ "${main#/}" = "$main" ]
    [ "$(readlink -f "$(dirname "$qmldir")/$main")" = "$(readlink -f "$STOCK/org.kde.image/contents/ui/main.qml")" ]
    [ "$(readlink -f "$(dirname "$qmldir")/$config")" = "$(readlink -f "$STOCK/org.kde.image/contents/ui/config.qml")" ]
}

@test "an overlay carries the wrappers and every QML file of the add-on" {
    "$TOOL" sync --quiet
    local ui=$OVERLAY/org.kde.image/contents/ui
    cmp "$REPO/wrappers/main.qml" "$ui/main.qml"
    cmp "$REPO/wrappers/config.qml" "$ui/config.qml"
    local f
    for f in "$REPO"/qml/*.qml; do
        cmp "$f" "$ui/plmblur/$(basename "$f")"
    done
}

@test "a plugin without a settings page gets the standalone one" {
    "$TOOL" sync --quiet
    local ui=$OVERLAY/org.kde.haenau/contents/ui
    cmp "$REPO/wrappers/config-standalone.qml" "$ui/config.qml"
    run grep -c StockConfig "$ui/stock/qmldir"
    [ "$output" = 0 ]
    grep -q StockMain "$ui/stock/qmldir"
}

@test "the schema gains the add-on's settings once and keeps the stock ones" {
    "$TOOL" sync --quiet
    local xml=$OVERLAY/org.kde.color/contents/config/main.xml
    [ "$(grep -c 'name="LoginBlurIntensity"' "$xml")" -eq 1 ]
    [ "$(grep -c 'name="LoginBlurStyle"' "$xml")" -eq 1 ]
    [ "$(grep -c 'name="LoginBlurDebug"' "$xml")" -eq 1 ]
    [ "$(grep -c 'name="Color"' "$xml")" -eq 1 ]
    if command -v xmllint >/dev/null; then
        xmllint --noout "$xml"
    fi
}

@test "a plugin without a schema gets one with the add-on's settings" {
    "$TOOL" sync --quiet
    local xml=$OVERLAY/org.kde.haenau/contents/config/main.xml
    [ "$(grep -c 'name="LoginBlurIntensity"' "$xml")" -eq 1 ]
    [ "$(grep -c 'name="LoginBlurStyle"' "$xml")" -eq 1 ]
    if command -v xmllint >/dev/null; then
        xmllint --noout "$xml"
    fi
}

@test "sync twice gives the same result as sync once" {
    "$TOOL" sync --quiet
    cp -a "$OVERLAY" "$BATS_TEST_TMPDIR/first"
    "$TOOL" sync --quiet
    diff -r "$BATS_TEST_TMPDIR/first" "$OVERLAY"
}

@test "sync leaves no temporary directories behind" {
    "$TOOL" sync --quiet
    run find "$OVERLAY" -mindepth 1 -maxdepth 1 -name '.*'
    [ -z "$output" ]
}

@test "a directory the tool did not create is left alone, by sync and by remove" {
    mkdir -p "$OVERLAY/org.kde.image"
    echo "the administrator's own override" > "$OVERLAY/org.kde.image/README"
    run "$TOOL" sync
    [ "$status" -eq 0 ]
    [[ "$output" == *"was not created by plasma-login-blur-slider"* ]]
    [ "$(cat "$OVERLAY/org.kde.image/README")" = "the administrator's own override" ]
    [ ! -e "$OVERLAY/org.kde.image/contents" ]
    # the others are still done
    [ -f "$OVERLAY/org.kde.color/.plasma-login-blur-slider" ]

    "$TOOL" remove --quiet
    [ -f "$OVERLAY/org.kde.image/README" ]
    [ ! -e "$OVERLAY/org.kde.color" ]
}

@test "the overlay of a plugin that was uninstalled goes away at the next sync" {
    "$TOOL" sync --quiet
    rm -rf "$STOCK/org.kde.color"
    run "$TOOL" sync
    [ "$status" -eq 0 ]
    [ ! -e "$OVERLAY/org.kde.color" ]
    [ -d "$OVERLAY/org.kde.image" ]
}

@test "the overlay of a plugin that is no longer on the list goes away at the next sync" {
    "$TOOL" sync --quiet
    echo 'PLUGINS="org.kde.image"' >> "$TOOL_CONF"
    "$TOOL" sync --quiet
    [ -d "$OVERLAY/org.kde.image" ]
    [ ! -e "$OVERLAY/org.kde.color" ]
    [ ! -e "$OVERLAY/org.kde.haenau" ]
}

@test "PLUGINS=all overlays every installed plugin" {
    echo 'PLUGINS=all' >> "$TOOL_CONF"
    "$TOOL" sync --quiet
    [ -d "$OVERLAY/org.example.other" ]
    [ -d "$OVERLAY/org.kde.image" ]
}

@test "remove deletes every overlay and the directories sync created" {
    "$TOOL" sync --quiet
    run "$TOOL" remove
    [ "$status" -eq 0 ]
    [ ! -e "$OVERLAY" ]
    [ ! -e "$(dirname "$OVERLAY")" ]
    # the stock plugins are untouched
    [ -f "$STOCK/org.kde.image/contents/ui/main.qml" ]
}

@test "remove without anything installed is not an error" {
    run "$TOOL" remove
    [ "$status" -eq 0 ]
}

@test "sync and remove refuse to run without root" {
    if [ "$(real_uid)" -eq 0 ]; then
        skip "running as real root"
    fi
    run env -u LD_PRELOAD -u FAKEROOTKEY "$TOOL" sync
    [ "$status" -eq 1 ]
    [[ "$output" == *"must be run as root"* ]]
    run env -u LD_PRELOAD -u FAKEROOTKEY "$TOOL" remove
    [ "$status" -eq 1 ]
}

@test "relative paths in the configuration are rejected" {
    echo 'OVERLAY_ROOT=relative/path' >> "$TOOL_CONF"
    run "$TOOL" sync
    [ "$status" -eq 1 ]
    [[ "$output" == *"absolute paths"* ]]
}
