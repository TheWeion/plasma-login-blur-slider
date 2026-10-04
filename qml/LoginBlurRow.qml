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
 * The "Blur intensity" row shown in the Login Screen settings.
 * Created by LoginBlurConfig.qml as a child of the page's Kirigami.FormLayout.
 */
RowLayout {
    id: row

    // The wallpaper configuration page that owns cfg_LoginBlurIntensity.
    required property Item configRoot

    readonly property int percent: configRoot ? configRoot.cfg_LoginBlurIntensity : 100
    readonly property int defaultPercent: configRoot ? configRoot.cfg_LoginBlurIntensityDefault : 100

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

        value: row.percent
        onMoved: {
            if (row.configRoot) {
                row.configRoot.cfg_LoginBlurIntensity = Math.round(value);
            }
        }

        Accessible.name: i18nd("plasma-login-blur-slider", "Blur intensity")

        QQC2.ToolTip.text: i18nd("plasma-login-blur-slider", "How strongly the wallpaper is blurred behind the login prompt")
        QQC2.ToolTip.visible: hovered && !pressed
        QQC2.ToolTip.delay: Kirigami.Units.toolTipDelay

        KCM.SettingHighlighter {
            highlight: row.percent !== row.defaultPercent
        }
    }

    QQC2.Label {
        Layout.minimumWidth: percentMetrics.width

        text: row.percent <= 0
            ? i18ndc("plasma-login-blur-slider", "@info the blur is switched off", "Off")
            : i18ndc("plasma-login-blur-slider", "@info blur intensity in percent", "%1%", row.percent)
        textFormat: Text.PlainText

        TextMetrics {
            id: percentMetrics
            text: "100%"
        }
    }
}
