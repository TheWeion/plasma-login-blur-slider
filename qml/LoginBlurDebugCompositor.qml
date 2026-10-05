/*
    SPDX-FileCopyrightText: 2026 Terry Fallows <terry@weion.dev>
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import org.kde.plasma.workspace.dbus as DBus

/*
 * Part of the diagnostics (see LoginBlurDebug.qml): asks the login screen's
 * compositor (KWin) which effects it has loaded and which are drawing right
 * now, and for its description of the screens. Kept in its own file so that
 * the rest of the diagnostics still work where this D-Bus module is missing.
 */
QtObject {
    id: probe

    property string tag: ""

    function call(path, iface, member, args, onValue) {
        DBus.SessionBus.asyncCall({
            service: "org.kde.KWin",
            path: path,
            iface: iface,
            member: member,
            arguments: args
        }, reply => {
            try {
                onValue(reply.value);
            } catch (e) {
                console.warn(probe.tag, "compositor: unexpected answer to", member + ":", e);
            }
        }, error => {
            console.warn(probe.tag, "compositor: no answer to", member + ":", error && error.message ? error.message : error);
        });
    }

    function logActiveEffects(reason) {
        call("/Effects", "org.freedesktop.DBus.Properties", "Get", ["org.kde.kwin.Effects", "activeEffects"], value => {
            console.info(probe.tag, "compositor effects drawing right now (" + reason + "):", value && value.length ? value.join(", ") : "none");
        });
    }

    function logOverview() {
        call("/Effects", "org.freedesktop.DBus.Properties", "Get", ["org.kde.kwin.Effects", "loadedEffects"], value => {
            console.info(probe.tag, "compositor effects loaded:", value && value.length ? value.join(", ") : "none");
        });
        call("/KWin", "org.kde.KWin", "supportInformation", [], value => {
            const lines = String(value).split("\n");
            let from = lines.indexOf("Screens");
            let to = lines.indexOf("Loaded Plugins:");
            if (from < 0) {
                from = 0;
            }
            if (to < 0 || to - from > 140) {
                to = Math.min(lines.length, from + 140);
            }
            for (let i = from; i < to; ++i) {
                if (lines[i].trim().length > 0) {
                    console.info(probe.tag, "compositor:", lines[i]);
                }
            }
        });
    }
}
