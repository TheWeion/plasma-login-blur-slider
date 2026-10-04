/*
    SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts

import org.kde.kcmutils as KCM
import org.kde.kirigami as Kirigami

/*
 * Owned by a wallpaper plugin's configuration page (see wrappers/config.qml).
 *
 * When that page is shown inside Plasma Login Manager's "Login Screen"
 * settings module, this adds a "Blur intensity" row to the module's own form,
 * right below "Wallpaper type". The value is kept in the wallpaper's
 * cfg_LoginBlurIntensity property, so the module saves and restores it like
 * any other wallpaper setting.
 *
 * In every other host (desktop wallpaper dialog, Screen Locking settings) it
 * does nothing.
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

    readonly property Component rowComponent: Component {
        RowLayout {
            objectName: controller.rowObjectName

            Kirigami.FormData.label: i18nd("plasma-login-blur-slider", "Blur intensity:")
            Kirigami.FormData.buddyFor: slider

            spacing: Kirigami.Units.smallSpacing

            QQC2.Slider {
                id: slider

                Layout.preferredWidth: Kirigami.Units.gridUnit * 12

                from: 0
                to: 100
                stepSize: 5
                snapMode: QQC2.Slider.SnapAlways

                value: controller.configRoot ? controller.configRoot.cfg_LoginBlurIntensity : 100
                onMoved: {
                    if (controller.configRoot) {
                        controller.configRoot.cfg_LoginBlurIntensity = Math.round(value);
                    }
                }

                Accessible.name: i18nd("plasma-login-blur-slider", "Blur intensity")

                QQC2.ToolTip.text: i18nd("plasma-login-blur-slider", "How strongly the wallpaper is blurred behind the login prompt")
                QQC2.ToolTip.visible: hovered && !pressed
                QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

                KCM.SettingHighlighter {
                    highlight: controller.configRoot !== null
                        && controller.configRoot.cfg_LoginBlurIntensity !== controller.configRoot.cfg_LoginBlurIntensityDefault
                }
            }

            QQC2.Label {
                readonly property int percent: controller.configRoot ? controller.configRoot.cfg_LoginBlurIntensity : 100

                Layout.minimumWidth: percentMetrics.width

                text: percent <= 0
                    ? i18ndc("plasma-login-blur-slider", "@info blur is disabled", "Off")
                    : i18ndc("plasma-login-blur-slider", "@info blur intensity in percent", "%1%", percent)
                textFormat: Text.PlainText

                TextMetrics {
                    id: percentMetrics
                    text: "100%"
                }
            }
        }
    }

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

        row = rowComponent.createObject(formLayout);
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
