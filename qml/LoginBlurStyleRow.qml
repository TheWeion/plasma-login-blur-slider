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
 * The "Blur style" row shown in the Login Screen and Screen Locking
 * settings, below the "Blur intensity" row (LoginBlurRow.qml). Created by
 * LoginBlurConfig.qml as a child of the page's Kirigami.FormLayout.
 */
RowLayout {
    id: row

    // The wallpaper configuration page that owns cfg_LoginBlurStyle.
    required property Item configRoot

    readonly property string style: configRoot && configRoot.cfg_LoginBlurStyle === "frosted" ? "frosted" : "standard"
    readonly property string defaultStyle: configRoot && configRoot.cfg_LoginBlurStyleDefault === "frosted" ? "frosted" : "standard"

    // A value taken over from the previous wallpaper type's page that has not
    // been applied yet (see LoginBlurConfig.qml); empty if there is none.
    property string pendingStyle: ""

    function indexOfStyle(name) {
        return name === "frosted" ? 1 : 0;
    }

    onStyleChanged: combo.currentIndex = indexOfStyle(style)

    Kirigami.FormData.label: i18nd("plasma-login-blur-slider", "Blur style:")
    Kirigami.FormData.buddyFor: combo

    spacing: Kirigami.Units.smallSpacing

    QQC2.ComboBox {
        id: combo

        textRole: "text"
        valueRole: "value"
        model: [
            {
                text: i18ndc("plasma-login-blur-slider", "@item:inlistbox the screen's own blur", "Standard"),
                value: "standard"
            },
            {
                text: i18ndc("plasma-login-blur-slider", "@item:inlistbox a smooth, strong blur", "Frosted glass"),
                value: "frosted"
            }
        ]

        Component.onCompleted: currentIndex = row.indexOfStyle(row.style)
        onActivated: {
            if (row.configRoot) {
                row.configRoot.cfg_LoginBlurStyle = currentValue;
            }
        }

        Accessible.name: i18nd("plasma-login-blur-slider", "Blur style")

        KCM.SettingHighlighter {
            highlight: row.style !== row.defaultStyle
        }
    }

    Kirigami.ContextualHelpButton {
        toolTipText: i18nd("plasma-login-blur-slider", "Standard is the blur this screen comes with. Frosted glass is a smooth blur like the blur effect of a desktop compositor, and much stronger at the same intensity: at about 25% it is as strong as Standard at 100%.")
    }
}
