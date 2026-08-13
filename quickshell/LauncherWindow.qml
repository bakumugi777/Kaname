import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Wayland

PanelWindow {
    id: window
    required property var launcherState
    visible: launcherState.active
    color: "transparent"
    function requestedScreen() {
        if (!launcherState.screenName) return null
        for (let i = 0; i < Quickshell.screens.length; ++i)
            if (Quickshell.screens[i].name === launcherState.screenName) return Quickshell.screens[i]
        return null
    }
    screen: requestedScreen()
    implicitWidth: Math.max(1100, Config.profileValue(launcherState.profile, "geometry", "width", Config.windowWidth))
    implicitHeight: Math.max(900, Config.profileValue(launcherState.profile, "geometry", "height", Config.windowHeight))
    anchors { right: true; bottom: true }
    exclusiveZone: 0
    focusable: visible
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: visible ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    WlrLayershell.namespace: "kaname"

    Item {
        id: content
        anchors.fill: parent
        focus: window.visible
        opacity: Config.profileValue(window.launcherState.profile, "opacity", "master", Config.masterOpacity)

        MouseArea {
            anchors.fill: parent
            onClicked: window.launcherState.cancel()
            onWheel: wheel => {
                const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y
                if (delta !== 0) window.launcherState.move(delta > 0 ? -1 : 1)
                wheel.accepted = true
            }
        }

        Canvas {
            id: guideCanvas
            anchors.fill: parent
            z: -3
            opacity: window.launcherState.presenting ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Config.motionDuration(Math.max(240, Config.animationMs)) }
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)

                const centerX = width + fanLayout.centerOffsetX
                const centerY = height + fanLayout.centerOffsetY
                const fullStart = fanLayout.startAngle * Math.PI / 180
                const fullEnd = fanLayout.endAngle * Math.PI / 180
                const centerAngle = (fullStart + fullEnd) / 2
                const opening = window.launcherState.openingProgress
                // Grow the start/end edges symmetrically from the center ray.
                const start = centerAngle + (fullStart - centerAngle) * opening
                const end = centerAngle + (fullEnd - centerAngle) * opening
                const outerRadius = fanLayout.radius + fanLayout.itemHeight * 0.82
                const innerRadius = Math.max(0, fanLayout.radius - fanLayout.itemHeight * 0.82)
                const returningToRoot = window.launcherState.bandCollapseActive
                    || (window.launcherState.parentReturnActive
                        && window.launcherState.navigationStack.length === 1)
                const growingRootBand = window.launcherState.childRevealActive
                    && window.launcherState.navigationStack.length === 1
                const fanAlpha = Config.profileValue(window.launcherState.profile, "opacity", "fan", Config.fanOpacity)
                // Keep the band recognisably translucent while giving the
                // bottom-right hub enough contrast for its labels. The radial
                // gradient is rebuilt from the live radius on every paint, so
                // it expands and contracts continuously with the hierarchy.
                // Keep the bottom-right information hub strongly legible,
                // then shed opacity quickly beyond it so the outer fan still
                // reads as translucent rather than as a dark slab.
                const fanInnerAlpha = Math.min(0.72, fanAlpha * 3.0)
                const fanOuterAlpha = Math.max(0.035, fanAlpha * 0.42)
                const fanColor = "rgba(" + Math.round(Theme.surface.r * 255) + ","
                    + Math.round(Theme.surface.g * 255) + ","
                    + Math.round(Theme.surface.b * 255) + ","
                // Keep the color field fixed in screen space. Using each
                // current band radius as the gradient endpoint changed the
                // alpha at every existing pixel whenever hierarchy geometry
                // changed, which looked like an opacity flash.
                const fixedGradientRadius = Math.max(900,
                    outerRadius, parentRing.capturedOuterRadius
                        + parentRing.capturedOuterItemHeight * 0.82)
                function fanGradient() {
                    const gradient = ctx.createRadialGradient(centerX, centerY, 0,
                        centerX, centerY, fixedGradientRadius)
                    gradient.addColorStop(0, fanColor + fanInnerAlpha + ")")
                    gradient.addColorStop(0.48, fanColor + (fanInnerAlpha * 0.88) + ")")
                    gradient.addColorStop(0.68, fanColor + (fanInnerAlpha * 0.36) + ")")
                    gradient.addColorStop(1, fanColor + fanOuterAlpha + ")")
                    return gradient
                }

                // During root <-> child transitions, growingBand owns the
                // complete surface. Leaving this canvas empty prevents two
                // translucent layers from accumulating during either handoff.
                if (!returningToRoot && !growingRootBand) {
                    ctx.fillStyle = fanGradient()
                    ctx.beginPath()
                    ctx.moveTo(centerX, centerY)
                    ctx.arc(centerX, centerY, innerRadius, start, end)
                    ctx.closePath()
                    ctx.fill()
                }

                if (!growingRootBand && !returningToRoot) {
                    ctx.fillStyle = fanGradient()
                    ctx.beginPath()
                    ctx.arc(centerX, centerY, outerRadius, start, end)
                    ctx.arc(centerX, centerY, innerRadius, end, start, true)
                    ctx.closePath()
                    ctx.fill()
                }

                // growingBand already owns this annulus during the final
                // child -> root return. Drawing the parent band underneath it
                // darkens the same translucent pixels before both disappear.
                if (window.launcherState.navigationStack.length > 0 && !returningToRoot) {
                    const parentOuter = parentRing.radius + 72
                    const parentInner = parentRing.radius - 72
                    const returningToRootBand = window.launcherState.navigationStack.length === 1
                        && (window.launcherState.parentReturnActive
                            || window.launcherState.bandCollapseActive
                            || window.launcherState.pendingBack !== null)
                    const parentBandOpacity = returningToRootBand
                        ? 1 - window.launcherState.parentReturnProgress
                        : window.launcherState.parentTransferActive
                            && window.launcherState.navigationStack.length === 1
                            ? window.launcherState.parentTransferProgress : 1
                    ctx.globalAlpha = parentBandOpacity
                    ctx.fillStyle = fanGradient()
                    ctx.beginPath()
                    ctx.arc(centerX, centerY, parentOuter, start, end)
                    ctx.arc(centerX, centerY, parentInner, end, start, true)
                    ctx.closePath()
                    ctx.fill()
                    ctx.globalAlpha = 1
                }

                ctx.globalAlpha = 1
            }
            Connections {
                target: Theme
                function onOutlineChanged() { guideCanvas.requestPaint() }
                function onSurfaceChanged() { guideCanvas.requestPaint() }
            }
            Connections {
                target: fanLayout
                function onRadiusChanged() { guideCanvas.requestPaint() }
                function onStartAngleChanged() { guideCanvas.requestPaint() }
                function onEndAngleChanged() { guideCanvas.requestPaint() }
                function onItemHeightChanged() { guideCanvas.requestPaint() }
            }
            Connections { target: Config; function onFanOpacityChanged() { guideCanvas.requestPaint() } }
            Connections {
                target: window.launcherState
                function onProfileChanged() { guideCanvas.requestPaint() }
                function onNavigationStackChanged() { guideCanvas.requestPaint() }
                function onParentTransferActiveChanged() { guideCanvas.requestPaint() }
                // Repaint on both edges: the start clears this background in
                // favour of growingBand, while the finish restores the normal
                // complete child surface before the transition layer retires.
                function onChildRevealActiveChanged() { guideCanvas.requestPaint() }
                function onChildDismissActiveChanged() { guideCanvas.requestPaint() }
                // growingBand owns the animated root-return geometry. Repaint
                // this full-window canvas only when that animation starts or
                // finishes, rather than once per bandCollapseProgress frame.
                function onBandCollapseActiveChanged() {
                    if (window.launcherState.bandCollapseActive)
                        guideCanvas.requestPaint()
                }
                // The normal fan is restored exactly when the parent ring
                // hands rendering back to FanLayout. Repaint in that same
                // state change so no blank Canvas frame is exposed.
                function onParentReturnActiveChanged() {
                    if (window.launcherState.parentReturnActive)
                        guideCanvas.requestPaint()
                }
                function onOpeningProgressChanged() { guideCanvas.requestPaint() }
            }
        }

        Canvas {
            id: growingBand
            anchors.fill: parent
            visible: (window.launcherState.childRevealActive
                && window.launcherState.navigationStack.length === 1)
                || window.launcherState.bandCollapseActive
                || (window.launcherState.parentReturnActive
                    && window.launcherState.navigationStack.length === 1)
            z: -2
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const growingRootBand = window.launcherState.childRevealActive
                    && window.launcherState.navigationStack.length === 1
                if (!growingRootBand && !window.launcherState.bandCollapseActive
                    && !(window.launcherState.parentReturnActive
                        && window.launcherState.navigationStack.length === 1)) return
                const centerX = width + fanLayout.centerOffsetX
                const centerY = height + fanLayout.centerOffsetY
                const start = fanLayout.startAngle * Math.PI / 180
                const end = fanLayout.endAngle * Math.PI / 180
                const childOuter = fanLayout.radius + fanLayout.itemHeight * 0.82
                const parentOuter = parentRing.capturedOuterRadius + parentRing.capturedOuterItemHeight * 0.82
                const progress = growingRootBand
                    ? window.launcherState.childRevealProgress
                    : window.launcherState.bandCollapseActive
                        ? window.launcherState.bandCollapseProgress : 0
                const outer = growingRootBand
                    ? parentOuter + (childOuter - parentOuter) * progress
                    : parentOuter + (childOuter - parentOuter) * progress
                const fanAlpha = Config.profileValue(window.launcherState.profile, "opacity", "fan", Config.fanOpacity)
                const fanInnerAlpha = Math.min(0.72, fanAlpha * 3.0)
                const fanOuterAlpha = Math.max(0.035, fanAlpha * 0.42)
                const fanColor = "rgba(" + Math.round(Theme.surface.r * 255) + ","
                    + Math.round(Theme.surface.g * 255) + ","
                    + Math.round(Theme.surface.b * 255) + ","
                // Match guideCanvas exactly: geometry changes, while the
                // underlying color/alpha field remains fixed in screen space.
                const fixedGradientRadius = Math.max(900, childOuter, parentOuter)
                const gradient = ctx.createRadialGradient(centerX, centerY, 0,
                    centerX, centerY, fixedGradientRadius)
                gradient.addColorStop(0, fanColor + fanInnerAlpha + ")")
                gradient.addColorStop(0.48, fanColor + (fanInnerAlpha * 0.88) + ")")
                gradient.addColorStop(0.68, fanColor + (fanInnerAlpha * 0.36) + ")")
                gradient.addColorStop(1, fanColor + fanOuterAlpha + ")")
                // Geometry alone reveals or collapses the surface. An opacity
                // fade would change its color during the handoff.
                ctx.globalAlpha = 1
                ctx.fillStyle = gradient
                ctx.beginPath()
                // Both directions use one complete surface, not an annulus
                // layered over guideCanvas. At progress 0 this exactly matches
                // the captured root outer edge; at progress 1 it exactly
                // matches the child surface.
                ctx.moveTo(centerX, centerY)
                ctx.arc(centerX, centerY, outer, start, end)
                ctx.closePath()
                ctx.fill()
                ctx.globalAlpha = 1
            }
            Connections {
                target: window.launcherState
                function onChildRevealProgressChanged() { growingBand.requestPaint() }
                function onChildRevealActiveChanged() { growingBand.requestPaint() }
                function onNavigationStackChanged() { growingBand.requestPaint() }
                function onChildDismissActiveChanged() { growingBand.requestPaint() }
                function onBandCollapseProgressChanged() { growingBand.requestPaint() }
                function onBandCollapseActiveChanged() { growingBand.requestPaint() }
                function onParentReturnActiveChanged() { growingBand.requestPaint() }
            }
            Connections {
                target: Theme
                function onSurfaceChanged() { growingBand.requestPaint() }
            }
        }

        // Decorative guides live on their own stable layer. They no longer
        // disappear, darken, or get rebuilt as part of a background handoff.
        Canvas {
            id: guidesCanvas
            anchors.fill: parent
            z: -1
            opacity: window.launcherState.presenting ? 1 : 0
            Behavior on opacity {
                NumberAnimation { duration: Config.motionDuration(Math.max(240, Config.animationMs)) }
            }
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const centerX = width + fanLayout.centerOffsetX
                const centerY = height + fanLayout.centerOffsetY
                const fullStart = fanLayout.startAngle * Math.PI / 180
                const fullEnd = fanLayout.endAngle * Math.PI / 180
                const centerAngle = (fullStart + fullEnd) / 2
                const opening = window.launcherState.openingProgress
                const start = centerAngle + (fullStart - centerAngle) * opening
                const end = centerAngle + (fullEnd - centerAngle) * opening
                const fixedGuideRadius = Math.max(fanLayout.radius, 760)
                const fixedGuideItemHeight = Math.max(fanLayout.itemHeight, 104)
                const fixedGuideInner = Math.max(0,
                    fixedGuideRadius - fixedGuideItemHeight * 0.82)
                const fixedGuideOuter = fixedGuideRadius + fixedGuideItemHeight * 0.82
                const fixedSpokeInner = parentRing.radius - 95

                ctx.strokeStyle = Theme.outline
                ctx.globalAlpha = Config.guideOpacity
                ctx.lineWidth = 1.4
                ctx.beginPath()
                ctx.arc(centerX, centerY, fixedGuideRadius, start, end)
                ctx.stroke()

                ctx.globalAlpha = Math.max(0.48, Config.guideOpacity)
                ctx.lineWidth = 1.8
                ctx.beginPath()
                ctx.arc(centerX, centerY, fixedGuideInner, start, end)
                ctx.stroke()

                ctx.globalAlpha = Config.guideOpacity
                ctx.lineWidth = 1.4
                ctx.beginPath()
                ctx.arc(centerX, centerY, fixedGuideOuter, start, end)
                ctx.arc(centerX, centerY, fixedGuideInner, start, end)
                ctx.arc(centerX, centerY, parentRing.radius, start, end)
                ctx.stroke()

                for (let i = 0; i < fanLayout.visibleCount; ++i) {
                    const angle = start + i * (end - start)
                        / Math.max(1, fanLayout.visibleCount - 1)
                    ctx.beginPath()
                    ctx.moveTo(centerX + Math.cos(angle) * fixedSpokeInner,
                               centerY + Math.sin(angle) * fixedSpokeInner)
                    ctx.lineTo(centerX + Math.cos(angle) * (fixedGuideOuter + 18),
                               centerY + Math.sin(angle) * (fixedGuideOuter + 18))
                    ctx.stroke()
                    ctx.fillStyle = Theme.primary
                    ctx.beginPath()
                    ctx.arc(centerX + Math.cos(angle) * (fixedGuideOuter + 18),
                            centerY + Math.sin(angle) * (fixedGuideOuter + 18),
                            2.4, 0, Math.PI * 2)
                    ctx.fill()
                }
                ctx.globalAlpha = 1
            }
            Connections {
                target: Theme
                function onOutlineChanged() { guidesCanvas.requestPaint() }
                function onPrimaryChanged() { guidesCanvas.requestPaint() }
            }
            Connections {
                target: fanLayout
                function onRadiusChanged() { guidesCanvas.requestPaint() }
                function onStartAngleChanged() { guidesCanvas.requestPaint() }
                function onEndAngleChanged() { guidesCanvas.requestPaint() }
                function onItemHeightChanged() { guidesCanvas.requestPaint() }
                function onVisibleCountChanged() { guidesCanvas.requestPaint() }
            }
            Connections { target: Config; function onGuideOpacityChanged() { guidesCanvas.requestPaint() } }
            Connections {
                target: window.launcherState
                function onOpeningProgressChanged() { guidesCanvas.requestPaint() }
            }
        }

        ParentRing {
            id: parentRing
            anchors.fill: parent
            state: window.launcherState
            outerRadius: fanLayout.radius
            outerCenterOffsetX: fanLayout.centerOffsetX
            outerCenterOffsetY: fanLayout.centerOffsetY
            outerSelectedAngle: fanLayout.selectedAngle
            // Parent/submenu cards are circular in FanLayout. Capture their
            // rendered square size, not the rectangular profile dimensions,
            // otherwise a deep-level return briefly interpolates through a
            // 150x104-style oval.
            outerItemWidth: window.launcherState.currentItem && window.launcherState.currentItem.isImage
                ? fanLayout.itemWidth : Math.min(fanLayout.itemWidth, fanLayout.itemHeight)
            outerItemHeight: fanLayout.itemHeight
            outerAngleStep: fanLayout.angleStep
            // Capture the actual layout rotation. selectedIndex is not a
            // substitute: lists of five or fewer keep rotationIndex at zero.
            outerRotationIndex: window.launcherState.rotationIndex
        }

        Connections {
            target: window.launcherState
            function onParentTransferStarting() {
                parentRing.captureTransferOrigin(fanLayout.liveItemPositions())
                window.launcherState.captureNavigationGeometry(parentRing.outerGeometry())
            }
            function onParentReturnStarting(geometry) {
                parentRing.captureReturnOrigin()
                parentRing.restoreReturnGeometry(geometry)
            }
            function onParentExitStarting() { parentRing.captureExitLayer() }
            function onAncestorEnterSnapshotRequested() { parentRing.captureAncestorEnterLayer() }
            function onParentReturnHandoffStarting() { parentRing.captureReturnHandoff() }
        }

        FanLayout {
            id: fanLayout
            anchors.fill: parent
            state: window.launcherState
            dismissTargets: parentRing.returnSourcePositions
            dismissTargetIndex: parentRing.selectedParent
            liveDismissTarget: parentRing.liveReturnTarget
            dismissBandRadius: parentRing.radius
            dismissBandCenterOffsetX: parentRing.centerOffsetX
            dismissBandCenterOffsetY: parentRing.centerOffsetY
            dismissBandStartAngle: parentRing.startAngle
            dismissBandEndAngle: parentRing.endAngle
            childRevealOrigin: parentRing.liveTransferOrigin
        }

        NumberAnimation {
            target: window.launcherState
            property: "openingProgress"
            from: 0; to: 1
            duration: Config.motionDuration(Math.max(360, Config.animationMs * 2))
            easing.type: Easing.OutCubic
            running: window.launcherState.presenting && !window.launcherState.closing
        }

        NumberAnimation {
            target: window.launcherState
            property: "openingProgress"
            from: 1; to: 0
            duration: window.launcherState.closeAnimationMs
            easing.type: Easing.InCubic
            running: window.launcherState.closing
        }

        NumberAnimation {
            target: window.launcherState
            property: "childRevealProgress"
            from: 0; to: 1
            duration: Config.motionDuration(Math.max(420, Config.animationMs * 2.4))
            easing.type: Easing.OutCubic
            running: window.launcherState.childRevealActive
            onFinished: window.launcherState.finishChildReveal()
        }

        NumberAnimation {
            target: window.launcherState
            property: "childDismissProgress"
            from: 1; to: 0
            duration: Config.motionDuration(Math.max(360, Config.animationMs * 2))
            easing.type: Easing.InOutCubic
            running: window.launcherState.childDismissActive
            onFinished: window.launcherState.finishChildDismiss()
        }

        NumberAnimation {
            target: window.launcherState
            property: "bandCollapseProgress"
            from: 1; to: 0
            duration: Config.motionDuration(Math.max(360, Config.animationMs * 2))
            easing.type: Easing.InOutCubic
            running: window.launcherState.bandCollapseActive
            onFinished: window.launcherState.finishBandCollapse()
        }

        NumberAnimation {
            target: window.launcherState
            property: "parentReturnProgress"
            from: 0; to: 1
            duration: Config.motionDuration(Math.max(360, Config.animationMs * 2))
            easing.type: Easing.OutCubic
            running: window.launcherState.parentReturnActive
            onFinished: window.launcherState.finishParentReturn()
        }

        Item {
            id: hub
            readonly property string selectedLabel: window.launcherState.currentItem
                ? window.launcherState.currentItem.label : window.launcherState.prompt
            readonly property real edgeMargin: 10
            width: 360
            height: width
            anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.rightMargin: edgeMargin; anchors.bottomMargin: edgeMargin
            opacity: window.launcherState.openingContentProgress
            scale: 0.92 + window.launcherState.openingContentProgress * 0.08
            Behavior on width { NumberAnimation { duration: Config.motionDuration(Math.max(300, Config.animationMs)); easing.type: Easing.OutCubic } }

            Text {
                id: labelMeasure
                visible: false
                text: hub.selectedLabel
                font.pixelSize: 23; font.weight: Font.Medium
            }

            Item {
                anchors.fill: parent

                Text {
                    id: titleLabel
                    anchors.top: parent.top; anchors.topMargin: parent.height * 0.27
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 42; anchors.rightMargin: 42
                    height: font.pixelSize * 2.4
                    text: hub.selectedLabel
                    color: Theme.text; font.pixelSize: 23; font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideNone
                }

                Text {
                    anchors.top: parent.top; anchors.topMargin: parent.height * 0.43
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: window.launcherState.items.length
                        ? (window.launcherState.selectedIndex + 1) + "  /  " + window.launcherState.items.length
                        : "0  /  0"
                    color: Theme.primary; font.pixelSize: 15; font.letterSpacing: 2
                }

                Rectangle {
                    id: circularSearch
                    width: Math.min(440, parent.width - 88); height: 54; radius: 27
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 58
                    color: Qt.rgba(0, 0, 0, 0.34)
                    border.color: window.launcherState.searchMode ? Theme.primary : Theme.outline
                    border.width: window.launcherState.searchMode ? 2 : 1
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter
                        text: "⌕"; color: Theme.primary; font.pixelSize: 24
                    }
                    TextInput {
                        id: searchInput
                        anchors.left: parent.left; anchors.leftMargin: 45
                        anchors.right: parent.right; anchors.rightMargin: 15
                        anchors.verticalCenter: parent.verticalCenter
                        text: window.launcherState.searchMode ? window.launcherState.query : "/  search"
                        color: window.launcherState.searchMode ? Theme.text : Theme.textMuted
                        font.pixelSize: 16; readOnly: !window.launcherState.searchMode
                        clip: true
                        onTextEdited: window.launcherState.setSearch(text)
                    }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: { window.launcherState.beginSearch(); searchInput.forceActiveFocus() }
                        onWheel: wheel => {
                            const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y
                            if (delta !== 0) window.launcherState.move(delta > 0 ? -1 : 1)
                            wheel.accepted = true
                        }
                    }
                }

                Text {
                    anchors.top: circularSearch.bottom; anchors.topMargin: 20
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 58; anchors.rightMargin: 58
                    text: window.launcherState.currentItem ? (window.launcherState.currentItem.description || "") : ""
                    color: Theme.textMuted; font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WrapAnywhere
                    lineHeight: 1.15
                    lineHeightMode: Text.ProportionalHeight
                }

            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Escape) {
                if (window.launcherState.searchMode) window.launcherState.endSearch()
                else window.launcherState.cancel()
                event.accepted = true
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                window.launcherState.accept(); event.accepted = true
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_Up) {
                window.launcherState.move(-1); event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_Down) {
                window.launcherState.move(1); event.accepted = true
            } else if (event.key === Qt.Key_Slash && !window.launcherState.searchMode) {
                window.launcherState.beginSearch(); searchInput.forceActiveFocus(); event.accepted = true
            } else if (event.key === Qt.Key_Backspace && !window.launcherState.searchMode) {
                if (window.launcherState.goBack()) event.accepted = true
            } else if (window.launcherState.triggerKey(event.text)) {
                event.accepted = true
            }
        }
    }
}
