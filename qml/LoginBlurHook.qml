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
 * With "LoginBlurStyle" set to "frosted" it also places a Gaussian blur of
 * the wallpaper (LoginBlurFrost.qml) over the stock effect, which then only
 * carries the transition.
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

    // "standard": the login screen's own blur, scaled by the intensity.
    // "frosted":  a Gaussian blur like the one a compositor's blur effect
    //             produces, smooth at every strength and much stronger at
    //             the top of the scale.
    readonly property string style: {
        const cfg = wallpaperItem ? wallpaperItem.configuration : null;
        return cfg && cfg.LoginBlurStyle === "frosted" ? "frosted" : "standard";
    }

    // Standard deviation, in pixels, of the frosted blur at 100%. For
    // comparison: the stock blur comes to about 14.5, and KWin's blur effect
    // (also Better Blur DX) to about 62 at strength 12 and 90 at its maximum
    // of 15.
    readonly property real frostMaxSigma: 64
    readonly property real frostSigma: frostMaxSigma * intensity

    // The stock blur's radius while the login prompt is fully shown. Under
    // the frosted blur it only shapes the transition: the frost fades in
    // over a picture that is going out of focus rather than over a sharp one.
    // It never gets stronger than the frost it leads up to (a radius of 50
    // is about as strong as a standard deviation of 14.5).
    readonly property real fullRadius: frostItem
        ? Math.min(stockRadius, frostSigma * 3.5)
        : stockRadius * intensity

    property Item blurItem: null
    property Item frostItem: null
    property int attempts: 0

    // Diagnostics, switched on with "plasma-login-blur-slider debug on".
    readonly property bool debugRequested: {
        const cfg = wallpaperItem ? wallpaperItem.configuration : null;
        return inLoginHelper && cfg !== null && cfg !== undefined && cfg.LoginBlurDebug === true;
    }
    property QtObject debugHelper: null

    function startDebug() {
        if (debugHelper || !debugRequested) {
            return;
        }
        const component = Qt.createComponent("LoginBlurDebug.qml");
        if (component.status !== Component.Ready) {
            console.warn("plasma-login-blur-slider: cannot load the diagnostics:", component.errorString());
            return;
        }
        debugHelper = component.createObject(hook, { hook: hook });
    }

    onDebugRequestedChanged: startDebug()

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
        if (style === "frosted" && intensity > 0) {
            frostItem = createFrost(blur, fader);
        }
        blur.radius = Qt.binding(() => hook.fullRadius * fader.factor);
        console.info("plasma-login-blur-slider: login wallpaper blur set to " + Math.round(intensity * 100) + "%"
            + (frostItem ? " (frosted glass)" : ""));
    }

    // The frosted blur goes into the stock blur item as a child, on top of
    // that item's own output: what the login screen's colour adjustment then
    // picks up is the stock blur with the frost faded in over it.
    function createFrost(blur, fader) {
        const component = Qt.createComponent("LoginBlurFrost.qml");
        if (component.status !== Component.Ready) {
            console.warn("plasma-login-blur-slider: cannot load the frosted glass blur, using the standard one:",
                component.errorString());
            return null;
        }
        const item = component.createObject(blur, { sourceItem: wallpaperItem });
        if (!item) {
            console.warn("plasma-login-blur-slider: cannot create the frosted glass blur, using the standard one");
            return null;
        }
        item.sigma = Qt.binding(() => hook.frostSigma);
        item.amount = Qt.binding(() => fader.factor);
        return item;
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

    Component.onCompleted: {
        tryHook();
        startDebug();
    }
}
