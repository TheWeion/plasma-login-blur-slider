/*
    SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Window

/*
 * Diagnostics for LoginBlurHook.qml. Only loaded when they have been switched
 * on with "plasma-login-blur-slider debug on".
 *
 * Writes to the journal what the login wallpaper process is doing (which
 * screen and size, whether the blur effect was found, the blur radius that is
 * actually in effect, how large the wallpaper image was loaded) and saves
 * screenshots of what this process itself renders, before the compositor and
 * the login prompt are put on top of it, to /tmp.
 */
QtObject {
    id: dbg

    required property QtObject hook

    readonly property Item wallpaperItem: hook ? hook.wallpaperItem : null
    readonly property var windowObject: wallpaperItem ? wallpaperItem.Window.window : null
    readonly property string tag: "plasma-login-blur-slider debug:"

    property int screenshots: 0
    property bool lastFlag: false

    // Asks the compositor about its effects; absent if that is not possible.
    property QtObject compositor: null

    function startCompositorProbe() {
        try {
            const component = Qt.createComponent("LoginBlurDebugCompositor.qml");
            if (component.status === Component.Ready) {
                compositor = component.createObject(dbg, { tag: tag });
            } else {
                console.info(tag, "compositor cannot be queried here:", component.errorString());
            }
        } catch (e) {
            console.info(tag, "compositor cannot be queried here:", e);
        }
    }

    function topItem() {
        let node = wallpaperItem;
        while (node && node.parent) {
            node = node.parent;
        }
        return node;
    }

    // The login screen's own root item for this window (the window's
    // internal content item above it cannot be captured).
    function sceneRoot() {
        let node = wallpaperItem;
        while (node && node.parent && node.parent.parent) {
            node = node.parent;
        }
        return node;
    }

    function typeName(object) {
        const text = String(object);
        const end = text.indexOf("(");
        return end > 0 ? text.substring(0, end) : text;
    }

    function num(value) {
        return typeof value === "number" ? Math.round(value * 100) / 100 : value;
    }

    function screenName() {
        try {
            return wallpaperItem.Screen.name || "(no name)";
        } catch (e) {
            return "(unknown)";
        }
    }

    function logState(reason) {
        try {
            const win = windowObject;
            const blur = hook.blurItem;
            const fader = blur ? blur.parent : null;
            console.info(tag, reason + ":",
                "screen=" + screenName(),
                "screenSize=" + wallpaperItem.Screen.width + "x" + wallpaperItem.Screen.height,
                "pixelRatio=" + num(wallpaperItem.Screen.devicePixelRatio),
                "window=" + (win ? win.width + "x" + win.height : "none"),
                "promptBlurRequested=" + (win ? win.blur : "n/a"),
                "wallpaper=" + num(wallpaperItem.width) + "x" + num(wallpaperItem.height),
                "effectFound=" + (blur !== null),
                "faderFactor=" + (fader ? num(fader.factor) : "n/a"),
                "blurRadius=" + (blur ? num(blur.radius) : "n/a"),
                "intensitySetting=" + Math.round(hook.intensity * 100) + "%",
                "style=" + hook.style,
                "frost=" + (hook.frostItem
                    ? "sigma " + num(hook.frostItem.sigma) + " (1/" + hook.frostItem.reduction + " size, kernel radius "
                        + hook.frostItem.kernelRadius + ") shown " + num(hook.frostItem.amount)
                    : "none"),
                "graphicsApi=" + wallpaperItem.GraphicsInfo.api);
        } catch (e) {
            console.warn(tag, "could not read the state:", e);
        }
    }

    // Items that display a picture, with the size the picture was loaded at.
    function collectImages(node, depth, lines) {
        if (!node || depth > 12) {
            return;
        }
        const kids = node.children;
        for (let i = 0; i < kids.length; ++i) {
            const child = kids[i];
            if (child.fillMode !== undefined && child.status !== undefined) {
                lines.push(typeName(child)
                    + " shown at " + num(child.width) + "x" + num(child.height)
                    + ", picture loaded at " + num(child.implicitWidth) + "x" + num(child.implicitHeight)
                    + ", status=" + child.status + ", fillMode=" + child.fillMode
                    + (child.visible ? "" : ", hidden")
                    + ", source=" + child.source);
            }
            collectImages(child, depth + 1, lines);
        }
    }

    function collectTree(node, depth, lines) {
        if (!node || depth > 7 || lines.length >= 70) {
            return;
        }
        const kids = node.children;
        for (let i = 0; i < kids.length; ++i) {
            const child = kids[i];
            let line = "  ".repeat(depth) + typeName(child) + " " + num(child.width) + "x" + num(child.height);
            if (!child.visible) {
                line += " hidden";
            }
            if (child.opacity !== 1) {
                line += " opacity=" + num(child.opacity);
            }
            if (typeof child.radius === "number") {
                line += " radius=" + num(child.radius);
            }
            if (typeof child.factor === "number") {
                line += " factor=" + num(child.factor);
            }
            if (child.layer && child.layer.enabled) {
                line += " layered";
            }
            if (child === wallpaperItem) {
                line += " <- the wallpaper";
            }
            lines.push(line);
            collectTree(child, depth + 1, lines);
        }
    }

    function logScene() {
        try {
            console.info(tag, "add-on files loaded from", Qt.resolvedUrl("."));

            const images = [];
            collectImages(wallpaperItem, 0, images);
            if (images.length === 0) {
                console.info(tag, "picture: no image item found in this wallpaper type");
            }
            for (const line of images) {
                console.info(tag, "picture:", line);
            }

            const tree = [];
            collectTree(topItem(), 0, tree);
            for (const line of tree) {
                console.info(tag, "scene:", line);
            }
        } catch (e) {
            console.warn(tag, "could not describe the scene:", e);
        }
    }

    // Saves what this process renders for its window (wallpaper plus the
    // login screen's own blur and colour adjustment, nothing else).
    function screenshot(name) {
        if (screenshots >= 8) {
            return;
        }
        try {
            const top = sceneRoot();
            if (!top || top === wallpaperItem) {
                return;
            }
            const path = "/tmp/plasma-login-blur-slider-" + screenName().replace(/[^A-Za-z0-9_-]/g, "_") + "-" + name + ".png";
            const started = top.grabToImage(function (result) {
                const saved = result.saveToFile(path);
                console.info(dbg.tag, "screenshot \"" + name + "\" of this process's own output",
                    saved ? "saved to " + path : "could NOT be saved to " + path);
            });
            if (started) {
                screenshots += 1;
            } else {
                console.warn(tag, "screenshot \"" + name + "\" could not be started");
            }
        } catch (e) {
            console.warn(tag, "screenshot failed:", e);
        }
    }

    readonly property Connections windowWatcher: Connections {
        target: dbg.windowObject
        ignoreUnknownSignals: true

        function onBlurChanged() {
            dbg.lastFlag = dbg.windowObject.blur;
            dbg.logState(dbg.lastFlag ? "login prompt shown, blur requested" : "login prompt hidden, blur no longer requested");
            dbg.settleTimer.restart();
        }
    }

    readonly property Timer settleTimer: Timer {
        interval: 2500
        onTriggered: {
            dbg.logState(dbg.lastFlag ? "prompt state settled" : "idle state settled");
            if (dbg.compositor) {
                dbg.compositor.logActiveEffects(dbg.lastFlag ? "login prompt shown" : "login prompt hidden");
            }
            dbg.screenshot(dbg.lastFlag ? "prompt" : "idle");
        }
    }

    readonly property Timer startTimer: Timer {
        interval: 4000
        running: true
        onTriggered: {
            dbg.logState("4 s after start");
            dbg.logScene();
            if (dbg.compositor) {
                dbg.compositor.logOverview();
                dbg.compositor.logActiveEffects("4 s after start");
            }
            // Named after when it is taken: the login screen may well be
            // showing its prompt at this point.
            dbg.screenshot("4s-after-start");
        }
    }

    Component.onCompleted: {
        console.info(tag, "diagnostics are on for this wallpaper window");
        startCompositorProbe();
    }
}
