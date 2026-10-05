#!/bin/sh
# SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors
# SPDX-License-Identifier: GPL-3.0-or-later
#
# Lints the QML the way it is deployed: the wrappers next to a "plmblur"
# directory with the add-on's QML and a "stock" directory, where a stand-in
# takes the place of the stock wallpaper plugin they inherit from.
#
# Needs qmllint (Qt 6) and, for the imports to resolve, the KDE modules the
# QML uses (Kirigami, KCMUtils, Plasma Workspace, Qt5Compat).

set -eu

root=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)

qmllint=""
for candidate in qmllint6 qmllint-qt6 /usr/lib/qt6/bin/qmllint /usr/lib64/qt6/bin/qmllint qmllint; do
    if command -v "$candidate" >/dev/null 2>&1; then
        qmllint=$candidate
        break
    fi
done
if [ -z "$qmllint" ]; then
    echo "qmllint not found (Arch: pacman -S qt6-declarative)" >&2
    exit 1
fi

work=$(mktemp -d)
trap 'rm -rf -- "$work"' EXIT

for kind in with-config standalone; do
    ui=$work/$kind/contents/ui
    mkdir -p "$ui/plmblur" "$ui/stock"
    cp "$root"/qml/*.qml "$ui/plmblur/"
    cp "$root/wrappers/main.qml" "$ui/main.qml"
    printf 'import QtQuick\n\nItem {\n    property var configuration\n}\n' > "$ui/stock/StockMain.qml"
    printf 'StockMain 1.0 StockMain.qml\n' > "$ui/stock/qmldir"
    if [ "$kind" = with-config ]; then
        cp "$root/wrappers/config.qml" "$ui/config.qml"
        printf 'import QtQuick\n\nItem {\n}\n' > "$ui/stock/StockConfig.qml"
        printf 'StockConfig 1.0 StockConfig.qml\n' >> "$ui/stock/qmldir"
    else
        cp "$root/wrappers/config-standalone.qml" "$ui/config.qml"
    fi
done

# Two kinds of warning are how this code is meant to work, not mistakes:
#   missing-property  the hook and the settings rows work on whatever wallpaper
#                     plugin or settings page they find themselves in, and look
#                     its properties up at run time;
#   unqualified       i18nd() and friends, and the ids of the hosting settings
#                     page, come from the context the files are loaded into.
# Everything else counts.
status=0
for kind in with-config standalone; do
    ui=$work/$kind/contents/ui
    "$qmllint" --missing-property disable --unqualified disable --max-warnings 0 \
        "$ui/main.qml" "$ui/config.qml" "$ui"/plmblur/*.qml || status=1
done

if [ "$status" = 0 ]; then
    echo "QML: no warnings"
fi
exit "$status"
