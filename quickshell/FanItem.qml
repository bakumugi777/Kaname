import QtQuick
import Quickshell

Item {
    id: root
    required property var modelData
    required property bool selected
    property bool shown: true
    property real reveal: 1
    property real visualOpacity: 1
    property bool cacheActive: shown
    property bool circular: false
    property bool animateSelection: true
    property bool animateOpacity: true
    property bool animateFocus: true
    property real selectionGlowPulse: 0.45
    property real selectionGlowPresence: 0
    property bool suppressSelectionGlow: false
    property real selectionGlowVisibility: suppressSelectionGlow ? 0 : 1
    // Snapshot/parent-ring delegates suppress focus animations to avoid
    // handoff flicker, but may still need to preserve the selected glow.
    property bool forceSelectionGlow: false
    readonly property real effectiveSelectionGlowPresence: (forceSelectionGlow
        && selected ? 1 : selectionGlowPresence) * selectionGlowVisibility
    property real entranceScale: 1
    property real exitScale: 1
    readonly property var safeData: modelData || ({ label: "", image: "", isImage: false })
    readonly property string fallbackIconName: {
        switch (safeData.type) {
        case "submenu": return "folder"
        case "applications": return "view-app-grid-symbolic"
        case "provider": return "view-refresh"
        case "status": return "dialog-information"
        case "error": return "dialog-error"
        case "command": return "application-x-executable"
        // Desktop entries without a resolvable app-specific icon should still
        // look like launchable applications rather than falling back to text.
        default: return "application-x-executable"
        }
    }
    // Desktop/menu entries keep their declared icon. Plain dmenu candidates
    // receive a themed generic icon so every non-thumbnail item has a visual
    // identity, just as in the previous wofi presentation.
    readonly property string iconName: safeData.icon || fallbackIconName
    readonly property bool iconIsDirectSource: iconName.startsWith("/")
        || iconName.startsWith("file://") || iconName.startsWith("qrc:")
        || iconName.startsWith("image://")
    // Desktop files from Nix packages can provide either a themed Icon name
    // or an absolute icon file. Keep `check` enabled: a missing themed icon
    // must not become Qt's purple/black missing-texture tile. In that case we
    // show the intentional gear fallback below instead.
    readonly property string iconSource: !safeData.isImage
        ? (iconIsDirectSource
            ? (iconName.startsWith("/") ? "file://" + iconName : iconName)
            : Quickshell.iconPath(iconName, true))
        : ""
    // A hierarchy entry is not always normalized to `submenu`: application
    // sources and dynamic providers also open another level, while generic
    // JSON input may communicate that solely through a children array.
    readonly property bool opensLevel: safeData.type === "submenu"
        || safeData.type === "applications" || safeData.type === "provider"
        || (Array.isArray(safeData.children) && safeData.children.length > 0)
    property real itemOpacity: 0.92
    property real inactiveOpacity: Config.inactiveOpacity
    property real imageOpacity: Config.imageOpacity
    // Selection is communicated by the border/glow, not by brightening the
    // whole translucent card surface.
    readonly property real cardOpacity: inactiveOpacity
    readonly property color brightBorderColor: Qt.lighter(Theme.primary, 1.36)
    signal chosen()
    signal scrolled(real delta)
    signal focusRequested()

    onSelectedChanged: {
        glowIn.stop()
        glowOut.stop()
        if (Config.reducedMotion) {
            selectionGlowPresence = selected ? 1 : 0
        } else if (!animateFocus) {
            // Parent-return handoffs suppress delegate animations. Keep the
            // glow dark until that handoff ends, then start the normal reveal.
            selectionGlowPresence = 0
        } else if (selected) {
            glowIn.restart()
        } else {
            glowOut.restart()
        }
    }
    onForceSelectionGlowChanged: {
        // Hand the fully lit snapshot glow back to the normal delegate
        // without restarting its fade-in from zero.
        if (!forceSelectionGlow && selected)
            selectionGlowPresence = 1
    }
    onAnimateFocusChanged: {
        if (!animateFocus) {
            glowIn.stop()
            glowOut.stop()
            selectionGlowPresence = 0
        } else if (selected && !Config.reducedMotion
                   && !forceSelectionGlow && selectionGlowPresence < 0.999) {
            glowIn.stop()
            selectionGlowPresence = 0
            glowIn.restart()
        }
    }
    Component.onCompleted: {
        selectionGlowPresence = 0
        if (selected) {
            if (Config.reducedMotion) selectionGlowPresence = 1
            else if (animateFocus) glowIn.restart()
        }
    }

    scale: (selected ? 1.16 : 0.88) * entranceScale * exitScale
    // Dimming an entire delegate also dims its icon. Keep the icon, thumbnail,
    // and label fully legible; only the card itself is subdued when inactive.
    opacity: shown ? reveal * visualOpacity : 0
    enabled: shown
    Behavior on scale {
        enabled: root.animateSelection
        NumberAnimation { duration: Config.motionDuration(Config.animationMs); easing.type: Easing.OutCubic }
    }
    Behavior on opacity {
        enabled: root.animateOpacity
        NumberAnimation { duration: Config.motionDuration(Config.animationMs) }
    }
    Behavior on selectionGlowVisibility {
        NumberAnimation {
            duration: Config.motionDuration(root.suppressSelectionGlow
                ? 150 : Math.max(280, Config.animationMs * 1.6))
            easing.type: root.suppressSelectionGlow ? Easing.OutCubic : Easing.InOutCubic
        }
    }
    NumberAnimation {
        id: glowIn
        target: root
        property: "selectionGlowPresence"
        to: 1
        duration: Config.motionDuration(Math.max(480, Config.animationMs * 2.7))
        easing.type: Easing.InOutCubic
    }
    NumberAnimation {
        id: glowOut
        target: root
        property: "selectionGlowPresence"
        to: 0
        duration: Config.motionDuration(140)
        easing.type: Easing.OutQuad
    }
    SequentialAnimation on selectionGlowPulse {
        running: root.selected && root.shown
            && root.effectiveSelectionGlowPresence > 0.001 && !Config.reducedMotion
        loops: Animation.Infinite
        NumberAnimation {
            from: 0.12; to: 1
            duration: 620
            easing.type: Easing.InOutSine
        }
        NumberAnimation {
            from: 1; to: 0.12
            duration: 1350
            easing.type: Easing.InOutSine
        }
    }

    // Closely stacked translucent surfaces form a cheap outward glow. The
    // opaque card drawn above hides their centres, leaving only a soft falloff
    // around the selected contour.
    Item {
        anchors.fill: parent
        z: -1
        visible: root.effectiveSelectionGlowPresence > 0.001
        opacity: root.effectiveSelectionGlowPresence
            * (0.48 + root.selectionGlowPulse * 0.52)

        Rectangle {
            anchors.fill: parent; anchors.margins: -13
            radius: root.circular ? width / 2 : 31
            color: "transparent"
            border.width: 13
            border.color: Qt.rgba(Theme.tertiary.r, Theme.tertiary.g, Theme.tertiary.b, 0.05)
            transform: Translate { x: 1.5; y: -1 }
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: -10
            radius: root.circular ? width / 2 : 28
            color: "transparent"
            border.width: 10
            border.color: Qt.rgba(Theme.tertiary.r, Theme.tertiary.g, Theme.tertiary.b, 0.065)
            transform: Translate { x: 1; y: -0.5 }
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: -7
            radius: root.circular ? width / 2 : 25
            color: "transparent"
            border.width: 7
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.085)
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: -4
            radius: root.circular ? width / 2 : 22
            color: "transparent"
            border.width: 4
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.12)
        }
        Rectangle {
            anchors.fill: parent; anchors.margins: -2
            radius: root.circular ? width / 2 : 20
            color: "transparent"
            border.width: 2
            border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.17)
        }
    }

    Rectangle {
        anchors.fill: parent
        radius: root.circular ? width / 2 : 18
        // A stable dark matugen underlay separates every card from the brighter
        // holographic fan. Selection still belongs exclusively to the border
        // glow, so the interior does not flash when focus changes.
        color: Qt.rgba(Theme.controlSurface.r,
                       Theme.controlSurface.g,
                       Theme.controlSurface.b,
                       Math.max(0.42, Math.min(0.58, root.cardOpacity)))
        border.color: Qt.rgba(
            Theme.secondary.r + (root.brightBorderColor.r - Theme.secondary.r) * root.effectiveSelectionGlowPresence,
            Theme.secondary.g + (root.brightBorderColor.g - Theme.secondary.g) * root.effectiveSelectionGlowPresence,
            Theme.secondary.b + (root.brightBorderColor.b - Theme.secondary.b) * root.effectiveSelectionGlowPresence,
            root.cardOpacity + (1 - root.cardOpacity) * root.effectiveSelectionGlowPresence)
        border.width: 1 + 2 * root.effectiveSelectionGlowPresence

        // A permanent secondary ring marks items that open another level.
        // Keep it outside on idle items, but move it inside the selected card.
        // Otherwise the selection halo obscures both outer contours.
        Rectangle {
            anchors.fill: parent
            property real ringMargin: root.selected ? 6 : -4
            anchors.margins: ringMargin
            visible: root.circular && root.opensLevel
            z: 2
            radius: width / 2
            color: "transparent"
            border.color: root.selected ? Qt.lighter(Theme.tertiary, 1.3) : Theme.primary
            border.width: root.selected ? 2 : 1
            opacity: root.selected ? 0.92 : 0.48
            antialiasing: true

            Behavior on ringMargin {
                enabled: root.animateSelection
                NumberAnimation {
                    duration: Config.motionDuration(Config.animationMs)
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on opacity {
                enabled: root.animateFocus
                NumberAnimation { duration: Config.motionDuration(160) }
            }
            Behavior on border.color {
                enabled: root.animateFocus
                ColorAnimation { duration: Config.motionDuration(160) }
            }
        }

        Image {
            id: thumbnail
            anchors.fill: parent
            anchors.margins: 5
            visible: !!root.safeData.isImage && !!root.safeData.image
            source: visible && root.cacheActive ? "file://" + String(root.safeData.image) : ""
            asynchronous: true
            cache: true
            opacity: root.imageOpacity
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: width * 2
            sourceSize.height: height * 2
        }

        Image {
            width: 42; height: 42
            anchors.centerIn: parent
            visible: !root.safeData.isImage && root.iconSource.length > 0
            source: visible && root.cacheActive ? root.iconSource : ""
            asynchronous: true
            fillMode: Image.PreserveAspectFit
        }

        Text {
            anchors.centerIn: parent
            visible: !root.safeData.isImage && root.iconSource.length === 0
            text: "⚙"
            // The gear is an intentional fallback, not a selected-label
            // inversion. Keep it legible against the translucent card.
            color: Theme.text
            font.pixelSize: 40
            font.family: "Noto Sans Symbols 2"
        }

        Text {
            anchors.fill: parent
            anchors.margins: 10
            // An icon is the complete visual label for a circular item. The
            // full label/description remains available in the bottom-right
            // detail area, so it must not resize or crowd the item itself.
            visible: thumbnail.visible && thumbnail.status === Image.Error
            text: thumbnail.status === Image.Error ? "⚠ " + root.safeData.label : root.safeData.label
            color: Theme.text
            wrapMode: Text.NoWrap
            elide: Text.ElideRight
            maximumLineCount: 1
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }

        // A narrow inward falloff drawn above thumbnails and card contents.
        // Only the first ten pixels inside the contour receive light; the
        // centre of the item remains exactly at its normal color.
        Item {
            anchors.fill: parent
            visible: root.effectiveSelectionGlowPresence > 0.001
            opacity: root.effectiveSelectionGlowPresence
                * (0.48 + root.selectionGlowPulse * 0.52)

            Rectangle {
                anchors.fill: parent
                radius: root.circular ? width / 2 : 18
                color: "transparent"
                border.width: 10
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.05)
                antialiasing: true
            }
            Rectangle {
                anchors.fill: parent
                radius: root.circular ? width / 2 : 18
                color: "transparent"
                border.width: 6
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.08)
                antialiasing: true
            }
            Rectangle {
                anchors.fill: parent
                radius: root.circular ? width / 2 : 18
                color: "transparent"
                border.width: 3
                border.color: Qt.rgba(Theme.primary.r, Theme.primary.g, Theme.primary.b, 0.14)
                antialiasing: true
            }
        }

        Rectangle {
            visible: !!root.safeData.key
            width: 24; height: 24; radius: 12
            anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 6
            color: Theme.background
            border.color: Theme.outline
            Text { anchors.centerIn: parent; text: root.safeData.key || ""; color: Theme.text; font.bold: true }
        }
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onEntered: root.focusRequested()
        onClicked: root.chosen()
        onWheel: wheel => {
            const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y
            if (delta !== 0) root.scrolled(delta)
            wheel.accepted = true
        }
    }
}
