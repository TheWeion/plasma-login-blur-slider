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

    readonly property bool inLoginScreenSettings: {
        if (!dialog) {
            return false;
        }
        const action = dialog.authActionName;
        if (typeof action === "string" && action.indexOf("plasmalogin") !== -1) {
            return true;
        }
        return typeof dialog.resetSynchronizedSettings === "function" && dialog.sessionModel !== undefined;
    }

    property Item row: null

    function attach() {
        if (row || !inLoginScreenSettings || !formLayout || !configRoot) {
            return;
        }

        // When the wallpaper type is switched, the outgoing page is destroyed
        // only after the incoming one exists. Hide its row straight away.
        const siblings = formLayout.children;
        for (let i = 0; i < siblings.length; ++i) {
            if (siblings[i].objectName === rowObjectName) {
                siblings[i].visible = false;
            }
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
