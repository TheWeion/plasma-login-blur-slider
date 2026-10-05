/*
    SPDX-FileCopyrightText: 2026 plasma-login-blur-slider contributors
    SPDX-License-Identifier: GPL-3.0-or-later
*/

import QtQuick
import QtQuick.Window
import Qt5Compat.GraphicalEffects

/*
 * The "frosted glass" blur: a Gaussian blur of the wallpaper, the kind a
 * compositor's blur effect approximates, at any strength.
 *
 * LoginBlurHook.qml creates this as a child of the login or lock screen's own
 * blur item and fades it in over that with "amount". Being a child of that
 * item, it ends up in the picture the screen's colour adjustment is applied
 * to, exactly like the stock blur.
 *
 * A wide blur is expensive at full resolution and has no fine detail left to
 * show for it. So the wallpaper is reduced first, by a power of two chosen so
 * that the blur still spans a good four pixels of the reduced picture, blurred
 * there with an exact Gaussian kernel and scaled back up. Mipmaps make the
 * reduction a proper average rather than a sparse sampling. The result is
 * within a fraction of a percent of a full-resolution Gaussian blur at a tiny
 * fraction of the cost, and it is only computed again when the wallpaper
 * changes.
 */
Item {
    id: frost

    // What to blur: the wallpaper.
    property Item sourceItem: null
    // Standard deviation of the blur, in pixels of the item (not the display).
    property real sigma: 0
    // 0 … 1: how much of the blurred picture covers what is underneath.
    property real amount: 0

    readonly property real deviceSigma: sigma * Screen.devicePixelRatio
    readonly property int reduction: {
        const wanted = deviceSigma / 4;
        if (!(wanted >= 2)) {
            return 1;
        }
        return Math.min(32, Math.pow(2, Math.floor(Math.log(wanted) / Math.LN2)));
    }
    readonly property real reducedSigma: deviceSigma / reduction
    // Three standard deviations to either side: all but 0.3% of the kernel.
    readonly property int kernelRadius: Math.max(1, Math.ceil(reducedSigma * 3))

    anchors.fill: parent
    opacity: amount
    visible: amount > 0 && sigma > 0 && sourceItem !== null

    // What is on screen without any blur. For an opaque wallpaper that is
    // simply the wallpaper. Where a wallpaper is transparent, the window's
    // background colour shows through; and where it is translucent, it shows
    // twice over, because the screen draws its own (then unblurred)
    // copy of the wallpaper on top of the wallpaper itself. Blurring exactly
    // this picture, opaquely, keeps such wallpapers as dense as they are
    // without the blur and leaves nothing sharp showing through.
    Item {
        id: seen

        width: frost.width
        height: frost.height
        visible: false

        Rectangle {
            anchors.fill: parent
            color: frost.Window.window ? frost.Window.window.color : "black"
        }

        ShaderEffectSource {
            id: wallpaperCopy

            anchors.fill: parent
            sourceItem: frost.sourceItem
            live: true
            smooth: true
        }

        ShaderEffect {
            readonly property var source: wallpaperCopy

            anchors.fill: parent
            visible: frost.sourceItem !== null && frost.sourceItem.visible
        }
    }

    ShaderEffectSource {
        id: picture

        width: frost.width
        height: frost.height
        sourceItem: seen
        live: true
        smooth: true
        mipmap: frost.reduction > 1
        visible: false
    }

    GaussianBlur {
        id: gaussian

        width: Math.ceil(frost.width / frost.reduction)
        height: Math.ceil(frost.height / frost.reduction)
        source: picture
        radius: frost.kernelRadius
        samples: frost.kernelRadius * 2 + 1
        deviation: frost.reducedSigma
        transparentBorder: false
        visible: false
    }

    ShaderEffectSource {
        anchors.fill: parent
        sourceItem: gaussian
        live: true
        smooth: true
    }
}
