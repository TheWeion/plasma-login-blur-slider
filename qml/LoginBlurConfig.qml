/*
    SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick

/*
 * Owned by a wallpaper plugin's configuration page (see wrappers/config.qml).
 *
 * When that page is shown inside Plasma Login Manager's "Login Screen"
 * settings module, this adds a "Blur intensity" row (LoginBlurRow.qml) to the
 * module's own form, right below "Wallpaper type". The value lives in the
 * page's cfg_LoginBlurIntensity property, so the module loads, saves and
 * resets it like any other wallpaper setting.
 *
 * In every other host (desktop wallpaper dialog, Screen Locking settings) it
 * does nothing, and does not even load the row's QML.
 */
QtObject {
    id: controller

    // The configuration page's root item; owns cfg_LoginBlurIntensity.
    property Item configRoot: null
    // The hosting dialog/module ("configDialog" in wallpaper config pages).
    property var dialog: null
    // The hosting page's Kirigami.FormLayout.
    property Item formLayout: null

    readonly property string rowObjectName: "plasmaLoginBlurSliderRow"

    // Plasma Login Manager's settings module is recognised by API that only
    // it has (other hosts of wallpaper config pages lack all of these).
    readonly property bool inLoginScreenSettings: dialog !== null && dialog !== undefined
        && typeof dialog.synchronizeSettings === "function"
        && typeof dialog.resetSynchronizedSettings === "function"
        && dialog.sessionModel !== undefined

    // The module tells us when it reloads or resets its settings; without
    // that we cannot tell a reset from the user picking another wallpaper
    // type (see attach()).
    readonly property bool canWatchReloads: inLoginScreenSettings
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

    function attach() {
        if (row || !inLoginScreenSettings || !formLayout || !configRoot) {
            return;
        }

        // When the wallpaper type is switched, the outgoing page is destroyed
        // only after the incoming one exists. Hide its row straight away, and
        // remember what it was set to.
        let carried = -1;
        const siblings = formLayout.children;
        for (let i = 0; i < siblings.length; ++i) {
            const sibling = siblings[i];
            if (sibling.objectName !== rowObjectName) {
                continue;
            }
            if (sibling.visible && typeof sibling.percent === "number") {
                carried = sibling.percent;
            }
            sibling.visible = false;
        }

        const component = Qt.createComponent("LoginBlurRow.qml");
        if (component.status !== Component.Ready) {
            console.warn("plasma-login-blur-slider: cannot create the slider:", component.errorString());
            return;
        }
        row = component.createObject(formLayout, {
            objectName: rowObjectName,
            configRoot: configRoot
        });

        // The intensity is stored with the wallpaper type's settings. When
        // the user picks another type, keep what the slider was set to
        // instead of jumping back to that type's stored value. This has to
        // wait until the module has connected to our change signals, and must
        // not happen when the page was swapped by "Reset" or "Defaults".
        if (carried >= 0 && canWatchReloads) {
            Qt.callLater(() => {
                if (!controller.reloaded && controller.configRoot
                        && controller.configRoot.cfg_LoginBlurIntensity !== carried) {
                    controller.configRoot.cfg_LoginBlurIntensity = carried;
                }
            });
        }
    }

    onInLoginScreenSettingsChanged: attach()
    onFormLayoutChanged: attach()
    onConfigRootChanged: attach()

    Component.onCompleted: attach()
    Component.onDestruction: {
        if (row) {
            row.visible = false;
            row.destroy();
        }
    }
}
