/*
    SPDX-FileCopyrightText: 2026 Terry Fallows <terry@weion.dev>
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

/*
 * Owned by a wallpaper plugin's configuration page (see wrappers/config.qml).
 *
 * When that page is shown inside Plasma Login Manager's "Login Screen"
 * settings module or inside the "Screen Locking" settings module, this adds
 * a "Blur intensity" row (LoginBlurRow.qml) and a "Blur style" row
 * (LoginBlurStyleRow.qml) to the module's own form, right below "Wallpaper
 * type". The values live in the page's cfg_LoginBlurIntensity and
 * cfg_LoginBlurStyle properties, so the module loads, saves and resets them
 * like any other wallpaper setting: the login screen's with the login
 * screen's wallpaper settings, the lock screen's with the lock screen's.
 *
 * In every other host (the desktop wallpaper dialog) it does nothing, and
 * does not even load the rows' QML.
 */
QtObject {
    id: controller

    // The configuration page's root item; owns cfg_LoginBlurIntensity and
    // cfg_LoginBlurStyle.
    property Item configRoot: null
    // The hosting dialog/module ("configDialog" in wallpaper config pages).
    property var dialog: null
    // The hosting page's Kirigami.FormLayout.
    property Item formLayout: null
    // The hosting module's appearance page ("appearanceRoot"), if it has one.
    property Item pageHost: null

    readonly property string rowObjectName: "plasmaLoginBlurSliderRow"
    readonly property string styleRowObjectName: "plasmaLoginBlurStyleRow"

    // Plasma Login Manager's settings module is recognised by API that only
    // it has (other hosts of wallpaper config pages lack all of these).
    readonly property bool inLoginScreenSettings: dialog !== null && dialog !== undefined
        && typeof dialog.synchronizeSettings === "function"
        && typeof dialog.resetSynchronizedSettings === "function"
        && dialog.sessionModel !== undefined

    // The Screen Locking settings module, by API that only it has (its
    // second settings page was the look-and-feel theme's before it became
    // the shell's).
    readonly property bool inLockScreenSettings: dialog !== null && dialog !== undefined
        && !inLoginScreenSettings
        && (dialog.shellConfigFile !== undefined || dialog.lnfConfigFile !== undefined)
        && dialog.wallpaperIntegration !== undefined
        && dialog.isDefaultsAppearance !== undefined
        && typeof dialog.forceUpdateState === "function"

    readonly property bool inScreenSettings: inLoginScreenSettings || inLockScreenSettings

    // The Screen Locking module creates every configuration page twice:
    // first a throw-away instance, as a direct child of its appearance page,
    // to see which settings the page has, and then the real one inside its
    // stack view. The throw-away one must leave the form alone, or the real
    // one would take over the defaults it shows instead of the saved values.
    readonly property bool throwAway: pageHost !== null && configRoot !== null && configRoot.parent === pageHost

    // The module tells us when it reloads or resets its settings; without
    // that we cannot tell a reset from the user picking another wallpaper
    // type (see attach()).
    readonly property bool canWatchReloads: inScreenSettings
        && typeof dialog.loadCalled === "function"
        && typeof dialog.defaultsCalled === "function"

    property bool reloaded: false

    readonly property Connections reloadWatcher: Connections {
        target: controller.canWatchReloads ? controller.dialog : null
        ignoreUnknownSignals: true

        function onLoadCalled() {
            controller.reloaded = true;
        }
        function onDefaultsCalled() {
            controller.reloaded = true;
        }
    }

    property Item row: null
    property Item styleRow: null
    property bool attaching: false

    function createRow(file, layout, name, root) {
        const component = Qt.createComponent(file);
        if (component.status !== Component.Ready) {
            console.warn("plasma-login-blur-slider: cannot create " + file + ":", component.errorString());
            return null;
        }
        return component.createObject(layout, {
            objectName: name,
            configRoot: root
        });
    }

    function attach() {
        // Reading these properties can evaluate their bindings for the first
        // time, which calls this function again through the change handlers
        // below. So read everything before looking at "row": the nested call
        // then does the work and this one sees its result.
        const inSettings = inScreenSettings;
        const watching = canWatchReloads;
        const layout = formLayout;
        const root = configRoot;
        const scratch = throwAway;
        if (row || styleRow || attaching || !inSettings || scratch || !layout || !root) {
            return;
        }
        attaching = true;

        // When the wallpaper type is switched, the outgoing page is destroyed
        // only after the incoming one exists. Hide its rows straight away,
        // and remember what they were set to.
        let carriedPercent = -1;
        let carriedStyle = "";
        const siblings = layout.children;
        for (let i = 0; i < siblings.length; ++i) {
            const sibling = siblings[i];
            if (sibling.objectName === rowObjectName) {
                if (sibling.visible) {
                    carriedPercent = sibling.pendingPercent >= 0 ? sibling.pendingPercent : sibling.percent;
                }
                sibling.visible = false;
            } else if (sibling.objectName === styleRowObjectName) {
                if (sibling.visible) {
                    carriedStyle = sibling.pendingStyle !== "" ? sibling.pendingStyle : sibling.style;
                }
                sibling.visible = false;
            }
        }

        row = createRow("LoginBlurRow.qml", layout, rowObjectName, root);
        styleRow = createRow("LoginBlurStyleRow.qml", layout, styleRowObjectName, root);
        attaching = false;

        // Both settings are stored with the wallpaper type's settings. When
        // the user picks another type, keep what the controls were set to
        // instead of jumping to that type's stored values. This has to wait
        // until the module has connected to our change signals, and must not
        // happen when the page was swapped by "Reset" or "Defaults".
        if (!watching) {
            return;
        }
        const sliderTarget = row;
        const styleTarget = styleRow;
        let pending = false;
        if (sliderTarget && carriedPercent >= 0 && carriedPercent !== root.cfg_LoginBlurIntensity) {
            sliderTarget.pendingPercent = carriedPercent;
            pending = true;
        }
        if (styleTarget && carriedStyle !== "" && carriedStyle !== styleTarget.style) {
            styleTarget.pendingStyle = carriedStyle;
            pending = true;
        }
        if (!pending) {
            return;
        }
        Qt.callLater(() => {
            if (sliderTarget && sliderTarget.pendingPercent >= 0) {
                const value = sliderTarget.pendingPercent;
                sliderTarget.pendingPercent = -1;
                if (sliderTarget.visible && !controller.reloaded && controller.configRoot) {
                    controller.configRoot.cfg_LoginBlurIntensity = value;
                }
            }
            if (styleTarget && styleTarget.pendingStyle !== "") {
                const value = styleTarget.pendingStyle;
                styleTarget.pendingStyle = "";
                if (styleTarget.visible && !controller.reloaded && controller.configRoot) {
                    controller.configRoot.cfg_LoginBlurStyle = value;
                }
            }
        });
    }

    onInScreenSettingsChanged: attach()
    onFormLayoutChanged: attach()
    onConfigRootChanged: attach()
    onThrowAwayChanged: attach()

    Component.onCompleted: attach()
    Component.onDestruction: {
        if (row) {
            row.visible = false;
            row.destroy();
        }
        if (styleRow) {
            styleRow.visible = false;
            styleRow.destroy();
        }
    }
}
