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
    property real entranceScale: 1
    property real exitScale: 1
    readonly property var safeData: modelData || ({ label: "", image: "", isImage: false })
    readonly property string fallbackVisual: safeData.fallbackVisual || ""
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
    readonly property bool isSubmenu: safeData.type === "submenu"
    property real itemOpacity: 0.92
    property real inactiveOpacity: Config.inactiveOpacity
    property real imageOpacity: Config.imageOpacity
    readonly property real cardOpacity: selected ? itemOpacity : inactiveOpacity
    signal chosen()
    signal scrolled(real delta)
    signal focusRequested()

    onSelectedChanged: wallpaperTypeIcon.requestPaint()

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

    Rectangle {
        anchors.fill: parent
        radius: root.circular ? width / 2 : 18
        // Keep each item distinct from the fan while allowing the wallpaper
        // to show through. Darkening the generated surface avoids washed-out
        // cards on bright matugen palettes.
        color: Qt.rgba(Theme.surfaceContainer.r * 0.72,
                       Theme.surfaceContainer.g * 0.72,
                       Theme.surfaceContainer.b * 0.72,
                       0.38 * root.cardOpacity)
        border.color: root.selected
            ? Theme.primary
            : Qt.rgba(Theme.outline.r, Theme.outline.g, Theme.outline.b, root.cardOpacity)
        border.width: root.selected ? 3 : 1

        Rectangle {
            anchors.fill: parent
            anchors.margins: -7
            radius: root.circular ? width / 2 : 23
            color: "transparent"
            border.color: Theme.primary
            border.width: root.selected ? 2 : 0
            opacity: root.selected ? 0.55 : 0
            Behavior on opacity {
                enabled: root.animateFocus
                NumberAnimation { duration: Config.motionDuration(Config.animationMs) }
            }
        }

        // A permanent secondary ring marks items that open another level.
        // It is intentionally distinct from the stronger selection halo.
        Rectangle {
            anchors.fill: parent
            anchors.margins: -4
            visible: root.circular && root.isSubmenu
            radius: width / 2
            color: "transparent"
            border.color: Theme.primary
            border.width: 1
            opacity: root.selected ? 0.9 : 0.48
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

        Canvas {
            id: wallpaperTypeIcon
            width: 44
            height: 44
            anchors.centerIn: parent
            visible: !root.safeData.isImage && root.iconSource.length === 0
                && root.fallbackVisual.length > 0
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = Theme.text
                ctx.fillStyle = ctx.strokeStyle
                ctx.lineWidth = 3
                ctx.lineJoin = "round"

                if (root.fallbackVisual === "image") {
                    ctx.strokeRect(3, 6, 38, 31)
                    ctx.beginPath()
                    ctx.moveTo(7, 33)
                    ctx.lineTo(18, 21)
                    ctx.lineTo(25, 27)
                    ctx.lineTo(31, 19)
                    ctx.lineTo(39, 33)
                    ctx.stroke()
                    ctx.beginPath()
                    ctx.arc(14, 14, 3, 0, Math.PI * 2)
                    ctx.fill()
                } else {
                    ctx.strokeRect(3, 9, 38, 26)
                    ctx.beginPath()
                    ctx.moveTo(20, 15)
                    ctx.lineTo(20, 29)
                    ctx.lineTo(32, 22)
                    ctx.closePath()
                    ctx.fill()
                }
            }
            onVisibleChanged: requestPaint()
            Component.onCompleted: requestPaint()
        }

        Text {
            anchors.centerIn: parent
            visible: !root.safeData.isImage && root.iconSource.length === 0
                && root.fallbackVisual.length === 0
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
