#!/usr/bin/env bats
# SPDX-FileCopyrightText: 2026 Terry Fallows <terry@weion.dev>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The command line: options, and the commands that read and write the blur
# settings of the login screen and of the lock screen.

load helpers

setup() {
    common_setup
    standard_plugins
}

# The value of a key in [Greeter][Wallpaper][<plugin>][General] of a file.
wallpaper_setting() {
    kreadconfig6 --file "$1" --group Greeter --group Wallpaper --group "$2" --group General --key "$3" --default '(unset)'
}

@test "--version prints the name and the version" {
    run "$TOOL" --version
    [ "$status" -eq 0 ]
    [ "$output" = "plasma-login-blur-slider 9.9.9" ]
}

@test "--help lists every command" {
    run "$TOOL" --help
    [ "$status" -eq 0 ]
    local cmd
    for cmd in sync remove status get set style login-compositor debug report; do
        [[ "$output" == *"  $cmd"* ]]
    done
    [[ "$output" == *"--lock"* ]]
}

@test "no command prints the usage and fails" {
    run "$TOOL"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Usage:"* ]]
}

@test "unknown commands and options are rejected" {
    run "$TOOL" frobnicate
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown command"* ]]
    run "$TOOL" status --frobnicate
    [ "$status" -eq 1 ]
    [[ "$output" == *"unknown option"* ]]
}

@test "an invalid LOGIN_COMPOSITOR_BLUR is rejected" {
    echo 'LOGIN_COMPOSITOR_BLUR=sometimes' >> "$TOOL_CONF"
    run "$TOOL" status
    [ "$status" -eq 1 ]
    [[ "$output" == *"LOGIN_COMPOSITOR_BLUR"* ]]
}

@test "get prints 100 when nothing is set" {
    need_kconfig_tools
    run "$TOOL" get
    [ "$status" -eq 0 ]
    [ "$output" = 100 ]
}

@test "set stores the intensity with the wallpaper type in use" {
    need_kconfig_tools
    run "$TOOL" set 35
    [ "$status" -eq 0 ]
    [ "$(wallpaper_setting "$LOGIN_CONF" org.kde.image LoginBlurIntensity)" = 35 ]
    [ "$("$TOOL" get)" = 35 ]

    printf '[Greeter]\nWallpaperPluginId=org.kde.color\n' > "$LOGIN_CONF"
    "$TOOL" set 60 --quiet
    [ "$(wallpaper_setting "$LOGIN_CONF" org.kde.color LoginBlurIntensity)" = 60 ]
    [ "$(wallpaper_setting "$LOGIN_CONF" org.kde.image LoginBlurIntensity)" = '(unset)' ]
}

@test "set accepts 0 and 100 and nothing outside" {
    need_kconfig_tools
    "$TOOL" set 0 --quiet
    [ "$("$TOOL" get)" = 0 ]
    "$TOOL" set 100 --quiet
    [ "$("$TOOL" get)" = 100 ]
    local bad
    for bad in 101 abc 3.5 ''; do
        run "$TOOL" set "$bad"
        [ "$status" -eq 1 ]
        [[ "$output" == *"expected a number from 0 to 100"* ]]
    done
    # a negative number looks like an option, and is refused as one
    run "$TOOL" set -5
    [ "$status" -eq 1 ]
    [ "$("$TOOL" get)" = 100 ]
}

@test "set keeps the login configuration readable for the login screen" {
    need_kconfig_tools
    "$TOOL" set 35 --quiet
    [ "$(stat -c %a "$LOGIN_CONF")" = 644 ]
}

@test "style is standard unless set to frosted" {
    need_kconfig_tools
    [ "$("$TOOL" style)" = standard ]
    run "$TOOL" style frosted
    [ "$status" -eq 0 ]
    [ "$("$TOOL" style)" = frosted ]
    [ "$(wallpaper_setting "$LOGIN_CONF" org.kde.image LoginBlurStyle)" = frosted ]
}

@test "style standard leaves no entry behind" {
    need_kconfig_tools
    "$TOOL" style frosted --quiet
    "$TOOL" style standard --quiet
    [ "$("$TOOL" style)" = standard ]
    run grep -c LoginBlurStyle "$LOGIN_CONF"
    [ "$output" = 0 ]
}

@test "style rejects anything else" {
    need_kconfig_tools
    run "$TOOL" style glass
    [ "$status" -eq 1 ]
    [[ "$output" == *'expected "standard" or "frosted"'* ]]
}

@test "an unknown style in the configuration counts as standard" {
    need_kconfig_tools
    kwriteconfig6 --file "$LOGIN_CONF" --group Greeter --group Wallpaper --group org.kde.image --group General --key LoginBlurStyle sparkly
    [ "$("$TOOL" style)" = standard ]
}

@test "set and style for the login screen need root" {
    need_kconfig_tools
    if [ "$(real_uid)" -eq 0 ]; then
        skip "running as real root"
    fi
    run env -u LD_PRELOAD -u FAKEROOTKEY "$TOOL" set 35
    [ "$status" -eq 1 ]
    [[ "$output" == *"must be run as root"* ]]
    run env -u LD_PRELOAD -u FAKEROOTKEY "$TOOL" style frosted
    [ "$status" -eq 1 ]
}

@test "--lock reads and writes the lock screen's own settings" {
    need_kconfig_tools
    local lock=$XDG_CONFIG_HOME/kscreenlockerrc
    [ "$("$TOOL" get --lock)" = 100 ]
    [ "$("$TOOL" style --lock)" = standard ]

    "$TOOL" set 45 --lock --quiet
    "$TOOL" style frosted --lock --quiet
    [ "$("$TOOL" get --lock)" = 45 ]
    [ "$("$TOOL" style --lock)" = frosted ]
    [ "$(wallpaper_setting "$lock" org.kde.image LoginBlurIntensity)" = 45 ]
    [ "$(wallpaper_setting "$lock" org.kde.image LoginBlurStyle)" = frosted ]

    # the login screen's settings are a different matter
    [ "$("$TOOL" get)" = 100 ]
    [ "$("$TOOL" style)" = standard ]
    run grep -c LoginBlur "$LOGIN_CONF"
    [ "$output" = 0 ]
}

@test "--lock does not need root" {
    need_kconfig_tools
    if [ "$(real_uid)" -eq 0 ]; then
        skip "running as real root"
    fi
    run env -u LD_PRELOAD -u FAKEROOTKEY "$TOOL" set 45 --lock
    [ "$status" -eq 0 ]
    [ "$(env -u LD_PRELOAD -u FAKEROOTKEY "$TOOL" get --lock)" = 45 ]
}

@test "--lock removes entries that are back at their defaults" {
    need_kconfig_tools
    local lock=$XDG_CONFIG_HOME/kscreenlockerrc
    "$TOOL" set 45 --lock --quiet
    "$TOOL" style frosted --lock --quiet
    "$TOOL" set 100 --lock --quiet
    "$TOOL" style standard --lock --quiet
    run grep -c LoginBlur "$lock"
    [ "$output" = 0 ]
}

@test "--lock follows the lock screen's wallpaper type" {
    need_kconfig_tools
    local lock=$XDG_CONFIG_HOME/kscreenlockerrc
    kwriteconfig6 --file "$lock" --group Greeter --key WallpaperPlugin org.kde.color
    "$TOOL" set 20 --lock --quiet
    [ "$(wallpaper_setting "$lock" org.kde.color LoginBlurIntensity)" = 20 ]
    [ "$(wallpaper_setting "$lock" org.kde.image LoginBlurIntensity)" = '(unset)' ]
}

@test "--lock points out a wallpaper type that has no overlay" {
    need_kconfig_tools
    "$TOOL" sync --quiet
    kwriteconfig6 --file "$XDG_CONFIG_HOME/kscreenlockerrc" --group Greeter --key WallpaperPlugin org.example.other
    run "$TOOL" set 20 --lock
    [ "$status" -eq 0 ]
    [[ "$output" == *"there is no overlay for org.example.other"* ]]
}

@test "status shows the overlays and the login screen's settings" {
    need_kconfig_tools
    "$TOOL" sync --quiet
    "$TOOL" set 35 --quiet
    "$TOOL" style frosted --quiet
    run "$TOOL" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"plasma-login-blur-slider 9.9.9"* ]]
    [[ "$output" =~ org\.kde\.image[[:space:]]+overlay\ active ]]
    [[ "$output" =~ org\.kde\.potd[[:space:]]+not\ installed ]]
    [[ "$output" == *"Login wallpaper type: org.kde.image"* ]]
    [[ "$output" =~ Blur\ intensity:[[:space:]]+35% ]]
    [[ "$output" =~ Blur\ style:[[:space:]]+frosted\ glass ]]
}

@test "debug on and off switch the diagnostics setting" {
    need_kconfig_tools
    "$TOOL" sync --quiet
    run "$TOOL" debug on
    [ "$status" -eq 0 ]
    [ "$(wallpaper_setting "$LOGIN_CONF" org.kde.image LoginBlurDebug)" = true ]
    run "$TOOL" debug off
    [ "$status" -eq 0 ]
    [ "$(wallpaper_setting "$LOGIN_CONF" org.kde.image LoginBlurDebug)" = '(unset)' ]
    run "$TOOL" debug maybe
    [ "$status" -eq 1 ]
}
