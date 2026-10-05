# SPDX-FileCopyrightText: 2026 Terry Fallows <terry@weion.dev>
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Shared setup for the unit tests.
#
# Every test gets a throw-away "system" below $BATS_TEST_TMPDIR: stock
# wallpaper plugins, an overlay directory, a login screen configuration and a
# home directory. The tool is pointed at it through its configuration file, so
# nothing of the real system is read or changed, and the login screen's
# compositor settings are left out of it altogether.

REPO=$(cd -- "$BATS_TEST_DIRNAME/../.." && pwd)

# make_plugin <id> [with-config]
make_plugin() {
    local dir=$STOCK/$1
    mkdir -p "$dir/contents/ui"
    printf '{ "KPlugin": { "Id": "%s", "Name": "%s" } }\n' "$1" "$1" > "$dir/metadata.json"
    printf 'import QtQuick\nItem {}\n' > "$dir/contents/ui/main.qml"
    if [ "${2:-}" = with-config ]; then
        mkdir -p "$dir/contents/config"
        printf 'import QtQuick\nItem {}\n' > "$dir/contents/ui/config.qml"
        {
            printf '%s\n' '<?xml version="1.0" encoding="UTF-8"?>'
            printf '%s\n' '<kcfg xmlns="http://www.kde.org/standards/kcfg/1.0">'
            printf '%s\n' '  <kcfgfile name=""/>'
            printf '%s\n' '  <group name="General">'
            printf '%s\n' '    <entry name="Color" type="Color">'
            printf '%s\n' '      <default>#000000</default>'
            printf '%s\n' '    </entry>'
            printf '%s\n' '  </group>'
            printf '%s\n' '</kcfg>'
        } > "$dir/contents/config/main.xml"
    fi
}

common_setup() {
    SYS=$BATS_TEST_TMPDIR/sys
    STOCK=$SYS/usr/share/plasma/wallpapers
    OVERLAY=$SYS/usr/local/share/plasma/wallpapers
    LOGIN_CONF=$SYS/etc/plasmalogin.conf
    TOOL_CONF=$SYS/etc/plasma-login-blur-slider.conf
    mkdir -p "$STOCK" "$SYS/etc" "$SYS/home/.config"

    {
        printf 'STOCK_ROOT=%s\n' "$STOCK"
        printf 'OVERLAY_ROOT=%s\n' "$OVERLAY"
        printf 'LOGIN_CONFIG=%s\n' "$LOGIN_CONF"
        printf 'LOGIN_USER=plbs-test-no-such-user\n'
        printf 'LOGIN_COMPOSITOR_BLUR=keep\n'
    } > "$TOOL_CONF"
    # Pin the wallpaper type, so that system-wide defaults of an installed
    # Plasma Login Manager cannot leak into the tests.
    printf '[Greeter]\nWallpaperPluginId=org.kde.image\n' > "$LOGIN_CONF"

    export PLASMA_LOGIN_BLUR_SLIDER_CONF=$TOOL_CONF
    export PLASMA_LOGIN_BLUR_SLIDER_DATADIR=$REPO
    export HOME=$SYS/home
    export XDG_CONFIG_HOME=$SYS/home/.config
    unset SUDO_USER

    TOOL=$BATS_TEST_TMPDIR/plasma-login-blur-slider
    sed -e 's|@VERSION@|9.9.9|g' -e "s|@DATADIR@|$REPO|g" \
        "$REPO/plasma-login-blur-slider.in" > "$TOOL"
    chmod +x "$TOOL"
}

# The usual set: two plugins with a settings page, one without, and one that
# is not on the tool's list.
standard_plugins() {
    make_plugin org.kde.image with-config
    make_plugin org.kde.color with-config
    make_plugin org.kde.haenau
    make_plugin org.example.other with-config
}

need_kconfig_tools() {
    if ! command -v kreadconfig6 >/dev/null || ! command -v kwriteconfig6 >/dev/null; then
        skip "kreadconfig6/kwriteconfig6 (KDE Frameworks) not installed"
    fi
}

# The user id outside of fakeroot.
real_uid() {
    env -u LD_PRELOAD -u FAKEROOTKEY id -u
}
