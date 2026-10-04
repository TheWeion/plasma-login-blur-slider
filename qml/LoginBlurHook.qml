/*
    SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

/*
 * Owned by a wallpaper plugin's root item (see wrappers/main.qml).
 *
 * When that wallpaper is being shown by Plasma Login Manager's wallpaper
 * helper (plasma-login-wallpaper), the helper covers it with a blur effect
 * whose radius is hardcoded. This item looks that effect up in the scene and
 * re-binds its radius so that it is scaled by the wallpaper's
 * "LoginBlurIntensity" setting.
 *
 * In every other process (desktop, lock screen, wallpaper previews) it does
 * nothing at all. If the helper's scene ever stops looking the way we expect,
 * nothing is touched and the stock blur stays in place.
 */
QtObject {
    id: hook

    // The wallpaper plugin's root item. Set by the wrapper.
    //
    // Note that this object is deliberately not a child item of the
    // wallpaper: WallpaperItem replaces (rather than appends to) its list of
    // children when a derived component declares any, which would throw away
    // the stock wallpaper's own contents.
    property Item wallpaperItem: null

    // Only ever act inside Plasma Login Manager's wallpaper helper.
    readonly property bool inLoginHelper: Qt.application.name === "plasma-login-wallpaper"

    // Radius Plasma Login Manager uses for a fully blurred wallpaper.
    readonly property real stockRadius: 50

    // 0.0 (no blur) … 1.0 (stock blur)
    readonly property real intensity: {
        const cfg = wallpaperItem ? wallpaperItem.configuration : null;
        const value = cfg ? Number(cfg.LoginBlurIntensity) : NaN;
        if (isNaN(value)) {
            return 1;
        }
        return Math.max(0, Math.min(100, value)) / 100;
    }

    property Item blurItem: null
    property int attempts: 0

    // Depth-first search for the effect that uses our wallpaper as its source.
    function findBlur(node, depth) {
        if (!node || depth > 8) {
            return null;
        }
        const kids = node.children;
        for (let i = 0; i < kids.length; ++i) {
            const child = kids[i];
            if (child === wallpaperItem) {
                continue; // never descend into the wallpaper itself
            }
            if (child.source === wallpaperItem && typeof child.radius === "number") {
                return child;
            }
            const found = findBlur(child, depth + 1);
            if (found) {
                return found;
            }
        }
        return null;
    }

    function tryHook() {
        if (blurItem || !inLoginHelper || !wallpaperItem) {
            return;
        }

        let top = wallpaperItem;
        while (top.parent) {
            top = top.parent;
        }
        if (top === wallpaperItem) {
            return; // not placed in the helper's scene yet
        }

        const blur = findBlur(top, 0);
        if (!blur) {
            return;
        }

        // The helper animates a 0…1 "factor" on the item that owns the blur.
        const fader = blur.parent;
        if (!fader || typeof fader.factor !== "number") {
            return;
        }

        blurItem = blur;
        blur.radius = Qt.binding(() => hook.stockRadius * hook.intensity * fader.factor);
        console.info("plasma-login-blur-slider: login wallpaper blur set to " + Math.round(intensity * 100) + "%");
    }

    readonly property Connections parentWatcher: Connections {
        target: hook.wallpaperItem
        function onParentChanged() {
            hook.tryHook();
        }
    }

    readonly property Timer retryTimer: Timer {
        interval: 100
        repeat: true
        running: hook.inLoginHelper && !hook.blurItem && hook.attempts < 100
        onTriggered: {
            hook.attempts += 1;
            hook.tryHook();
            if (!hook.blurItem && hook.attempts === 100) {
                console.warn("plasma-login-blur-slider: could not find the login screen's blur effect; leaving it untouched");
            }
        }
    }

    Component.onCompleted: tryHook()
}
