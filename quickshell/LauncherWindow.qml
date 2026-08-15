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
        property real fanDisplayMix: 0.24
        readonly property real darkFanOpacity: 1 - fanDisplayMix * 0.35

        MouseArea {
            anchors.fill: parent
            onClicked: window.launcherState.cancel()
            onWheel: wheel => {
                const delta = wheel.angleDelta.y !== 0 ? wheel.angleDelta.y : wheel.pixelDelta.y
                if (delta !== 0) window.launcherState.move(delta > 0 ? 1 : -1)
                wheel.accepted = true
            }
        }

        Canvas {
            id: guideCanvas
            anchors.fill: parent
            z: -3
            property real presentationOpacity: window.launcherState.presenting ? 1 : 0
            opacity: presentationOpacity * content.darkFanOpacity
            Behavior on presentationOpacity {
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
                // Let the surface approach transparency at its outer reach;
                // an opaque tail reads as a hard cut even without an outline.
                const fanOuterAlpha = 0
                const fanInnerColor = "rgba("
                    + Math.round((Theme.surface.r * 0.62 + Theme.primary.r * 0.30
                        + Theme.tertiary.r * 0.08) * 255) + ","
                    + Math.round((Theme.surface.g * 0.62 + Theme.primary.g * 0.30
                        + Theme.tertiary.g * 0.08) * 255) + ","
                    + Math.round((Theme.surface.b * 0.62 + Theme.primary.b * 0.30
                        + Theme.tertiary.b * 0.08) * 255) + ","
                const fanOuterColor = "rgba("
                    + Math.round((Theme.surface.r * 0.68 + Theme.secondary.r * 0.24
                        + Theme.primary.r * 0.08) * 255) + ","
                    + Math.round((Theme.surface.g * 0.68 + Theme.secondary.g * 0.24
                        + Theme.primary.g * 0.08) * 255) + ","
                    + Math.round((Theme.surface.b * 0.68 + Theme.secondary.b * 0.24
                        + Theme.primary.b * 0.08) * 255) + ","
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
                    gradient.addColorStop(0, fanInnerColor + fanInnerAlpha + ")")
                    gradient.addColorStop(0.48, fanInnerColor + (fanInnerAlpha * 0.88) + ")")
                    // Fade to zero at the real fan edge instead of clipping a
                    // still-visible fixed colour field at any hierarchy depth.
                    const fadeEnd = Math.max(0.56, Math.min(1,
                        outerRadius / fixedGradientRadius))
                    const fadeShoulder = Math.max(0.50, fadeEnd - 0.08)
                    gradient.addColorStop(fadeShoulder,
                        fanOuterColor + (fanInnerAlpha * 0.28) + ")")
                    gradient.addColorStop(fadeEnd, fanOuterColor + fanOuterAlpha + ")")
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

                ctx.globalAlpha = 1
            }
            Connections {
                target: Theme
                function onOutlineChanged() { guideCanvas.requestPaint() }
                function onSurfaceChanged() { guideCanvas.requestPaint() }
                function onPrimaryChanged() { guideCanvas.requestPaint() }
                function onSecondaryChanged() { guideCanvas.requestPaint() }
                function onTertiaryChanged() { guideCanvas.requestPaint() }
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
            opacity: content.darkFanOpacity
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
                const fanOuterAlpha = 0
                const fanInnerColor = "rgba("
                    + Math.round((Theme.surface.r * 0.62 + Theme.primary.r * 0.30
                        + Theme.tertiary.r * 0.08) * 255) + ","
                    + Math.round((Theme.surface.g * 0.62 + Theme.primary.g * 0.30
                        + Theme.tertiary.g * 0.08) * 255) + ","
                    + Math.round((Theme.surface.b * 0.62 + Theme.primary.b * 0.30
                        + Theme.tertiary.b * 0.08) * 255) + ","
                const fanOuterColor = "rgba("
                    + Math.round((Theme.surface.r * 0.68 + Theme.secondary.r * 0.24
                        + Theme.primary.r * 0.08) * 255) + ","
                    + Math.round((Theme.surface.g * 0.68 + Theme.secondary.g * 0.24
                        + Theme.primary.g * 0.08) * 255) + ","
                    + Math.round((Theme.surface.b * 0.68 + Theme.secondary.b * 0.24
                        + Theme.primary.b * 0.08) * 255) + ","
                // Match guideCanvas exactly: geometry changes, while the
                // underlying color/alpha field remains fixed in screen space.
                const fixedGradientRadius = Math.max(900, childOuter, parentOuter)
                const gradient = ctx.createRadialGradient(centerX, centerY, 0,
                    centerX, centerY, fixedGradientRadius)
                gradient.addColorStop(0, fanInnerColor + fanInnerAlpha + ")")
                gradient.addColorStop(0.48, fanInnerColor + (fanInnerAlpha * 0.88) + ")")
                // Tie the transparent endpoint to the animated outer edge.
                // `outer` already interpolates in both directions, so the
                // gradient remains continuous throughout root/child changes.
                const fadeEnd = Math.max(0.56, Math.min(1,
                    outer / fixedGradientRadius))
                const fadeShoulder = Math.max(0.50, fadeEnd - 0.08)
                gradient.addColorStop(fadeShoulder,
                    fanOuterColor + (fanInnerAlpha * 0.28) + ")")
                gradient.addColorStop(fadeEnd, fanOuterColor + fanOuterAlpha + ")")
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
                function onPrimaryChanged() { growingBand.requestPaint() }
                function onSecondaryChanged() { growingBand.requestPaint() }
                function onTertiaryChanged() { growingBand.requestPaint() }
            }
        }

        // A bright version of the exact fan surface. Crossfading this over the
        // normal dark fan makes the plane itself behave like a translucent,
        // self-emissive display; it is not an origin glow or an outer halo.
        Canvas {
            id: fanDisplayLightCanvas
            anchors.fill: parent
            z: -1.75
            property real displayRadius: fanLayout.radius + fanLayout.itemHeight * 0.82
            opacity: window.launcherState.openingContentProgress * content.fanDisplayMix
            onDisplayRadiusChanged: requestPaint()
            onPaint: {
                const ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                const centerX = width + fanLayout.centerOffsetX
                const centerY = height + fanLayout.centerOffsetY
                const start = fanLayout.startAngle * Math.PI / 180
                const end = fanLayout.endAngle * Math.PI / 180
                const centerAngle = (start + end) / 2
                const opening = window.launcherState.openingProgress
                const openedStart = centerAngle + (start - centerAngle) * opening
                const openedEnd = centerAngle + (end - centerAngle) * opening
                const outer = displayRadius
                function rgba(color, alpha) {
                    return "rgba(" + Math.round(color.r * 255) + ","
                        + Math.round(color.g * 255) + ","
                        + Math.round(color.b * 255) + "," + alpha + ")"
                }

                const displayColor = Qt.rgba(
                    Theme.surface.r * 0.22 + Theme.primary.r * 0.58 + Theme.tertiary.r * 0.20,
                    Theme.surface.g * 0.22 + Theme.primary.g * 0.58 + Theme.tertiary.g * 0.20,
                    Theme.surface.b * 0.22 + Theme.primary.b * 0.58 + Theme.tertiary.b * 0.20, 1)
                const fanAlpha = Config.profileValue(window.launcherState.profile,
                    "opacity", "fan", Config.fanOpacity)
                const innerAlpha = Math.min(0.72, fanAlpha * 3.0)
                const fixedGradientRadius = Math.max(900, outer)
                const fadeEnd = Math.max(0.56, Math.min(1, outer / fixedGradientRadius))
                const fadeShoulder = Math.max(0.50, fadeEnd - 0.08)
                const displaySurface = ctx.createRadialGradient(centerX, centerY, 0,
                    centerX, centerY, fixedGradientRadius)
                displaySurface.addColorStop(0, rgba(displayColor, innerAlpha))
                displaySurface.addColorStop(0.48, rgba(displayColor, innerAlpha * 0.88))
                displaySurface.addColorStop(fadeShoulder,
                    rgba(displayColor, innerAlpha * 0.28))
                displaySurface.addColorStop(fadeEnd, rgba(displayColor, 0))
                ctx.fillStyle = displaySurface
                ctx.beginPath()
                ctx.moveTo(centerX, centerY)
                ctx.arc(centerX, centerY, outer, openedStart, openedEnd)
                ctx.closePath()
                ctx.fill()
            }
            Behavior on displayRadius {
                NumberAnimation {
                    duration: Config.motionDuration(Math.max(420, Config.animationMs * 2.4))
                    easing.type: Easing.InOutCubic
                }
            }
            SequentialAnimation {
                running: window.launcherState.presenting
                    && !window.launcherState.closing && !Config.reducedMotion
                loops: Animation.Infinite
                NumberAnimation {
                    target: content; property: "fanDisplayMix"
                    from: 0.06; to: 0.62; duration: 3200; easing.type: Easing.InOutSine
                }
                NumberAnimation {
                    target: content; property: "fanDisplayMix"
                    from: 0.62; to: 0.06; duration: 3800; easing.type: Easing.InOutSine
                }
            }
            Connections {
                target: Theme
                function onSurfaceChanged() { fanDisplayLightCanvas.requestPaint() }
                function onPrimaryChanged() { fanDisplayLightCanvas.requestPaint() }
                function onTertiaryChanged() { fanDisplayLightCanvas.requestPaint() }
            }
            Connections {
                target: fanLayout
                function onCenterOffsetXChanged() { fanDisplayLightCanvas.requestPaint() }
                function onCenterOffsetYChanged() { fanDisplayLightCanvas.requestPaint() }
                function onStartAngleChanged() { fanDisplayLightCanvas.requestPaint() }
                function onEndAngleChanged() { fanDisplayLightCanvas.requestPaint() }
            }
            Connections {
                target: window.launcherState
                function onOpeningProgressChanged() { fanDisplayLightCanvas.requestPaint() }
                function onProfileChanged() { fanDisplayLightCanvas.requestPaint() }
            }
            Connections { target: Config; function onFanOpacityChanged() { fanDisplayLightCanvas.requestPaint() } }
        }

        // The parent-level accent band is a separate texture whose opacity is
        // animated by the scene graph. Keeping it out of guideCanvas avoids a
        // full-window Canvas repaint on every transfer-progress frame.
        Canvas {
            id: parentBandCanvas
            anchors.fill: parent
            z: -1.5
            visible: window.launcherState.navigationStack.length > 0
                || window.launcherState.parentTransferActive
                || window.launcherState.parentReturnActive
            opacity: {
                if (window.launcherState.navigationStack.length === 0) return 0
                const returningToRoot = window.launcherState.navigationStack.length === 1
                    && (window.launcherState.parentReturnActive
                        || window.launcherState.bandCollapseActive
                        || window.launcherState.pendingBack !== null)
                if (returningToRoot)
                    return 1 - window.launcherState.parentReturnProgress
                if (window.launcherState.navigationStack.length === 1
                    && window.launcherState.parentTransferActive)
                    return window.launcherState.parentTransferProgress
                return 1
            }
            onVisibleChanged: {
                if (visible) requestPaint()
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
                const parentOuter = parentRing.radius + 72
                const parentInner = parentRing.radius - 72
                const fanAlpha = Config.profileValue(window.launcherState.profile,
                    "opacity", "fan", Config.fanOpacity)
                const bandRed = Theme.surface.r * 0.30 + Theme.primary.r * 0.48
                    + Theme.secondary.r * 0.22
                const bandGreen = Theme.surface.g * 0.30 + Theme.primary.g * 0.48
                    + Theme.secondary.g * 0.22
                const bandBlue = Theme.surface.b * 0.30 + Theme.primary.b * 0.48
                    + Theme.secondary.b * 0.22
                // Parent hierarchy bands are accents, not another slice of
                // the fan's radial gradient. A constant alpha keeps the band
                // visually even from end to end.
                const bandAlpha = Math.min(0.24, Math.max(0.10, fanAlpha * 0.95))
                // Assign a QColor directly. An invalid CSS rgba string leaves
                // Context2D's default black fill active, producing an opaque
                // black hierarchy band regardless of the requested alpha.
                ctx.fillStyle = Qt.rgba(bandRed, bandGreen, bandBlue, bandAlpha)
                ctx.beginPath()
                ctx.arc(centerX, centerY, parentOuter, start, end)
                ctx.arc(centerX, centerY, parentInner, end, start, true)
                ctx.closePath()
                ctx.fill()
            }
            Connections {
                target: Theme
                function onSurfaceChanged() { parentBandCanvas.requestPaint() }
                function onPrimaryChanged() { parentBandCanvas.requestPaint() }
                function onSecondaryChanged() { parentBandCanvas.requestPaint() }
            }
            Connections {
                target: fanLayout
                function onRadiusChanged() { parentBandCanvas.requestPaint() }
                function onStartAngleChanged() { parentBandCanvas.requestPaint() }
                function onEndAngleChanged() { parentBandCanvas.requestPaint() }
                function onItemHeightChanged() { parentBandCanvas.requestPaint() }
            }
            Connections {
                target: window.launcherState
                function onProfileChanged() { parentBandCanvas.requestPaint() }
                function onOpeningProgressChanged() { parentBandCanvas.requestPaint() }
            }
            Connections { target: Config; function onFanOpacityChanged() { parentBandCanvas.requestPaint() } }
        }

        // Decorative guides live on their own stable layer. They no longer
        // disappear, darken, or get rebuilt as part of a background handoff.
        Canvas {
            id: guidesCanvas
            anchors.fill: parent
            z: -1
            property real hierarchyPulseProgress: 0
            property bool hierarchyPulseReverse: false
            onHierarchyPulseProgressChanged: requestPaint()
            function startHierarchyPulse(reverse) {
                hierarchyPulseReverse = reverse
                hierarchyPulseProgress = 0
                guideHierarchyPulse.restart()
            }
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

                ctx.strokeStyle = Theme.secondary
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
                ctx.arc(centerX, centerY, parentRing.radius, start, end)
                ctx.stroke()

                for (let i = 0; i < fanLayout.visibleCount; ++i) {
                    const angle = start + i * (end - start)
                        / Math.max(1, fanLayout.visibleCount - 1)
                    const pulsePosition = (hierarchyPulseReverse
                        ? 1 - hierarchyPulseProgress : hierarchyPulseProgress)
                        * Math.max(1, fanLayout.visibleCount - 1)
                    const pulse = Math.max(0, 1 - Math.abs(i - pulsePosition) / 1.35)
                    ctx.globalAlpha = Math.min(0.78,
                        Config.guideOpacity + pulse * 0.42)
                    ctx.beginPath()
                    ctx.moveTo(centerX + Math.cos(angle) * fixedSpokeInner,
                               centerY + Math.sin(angle) * fixedSpokeInner)
                    ctx.lineTo(centerX + Math.cos(angle) * (fixedGuideOuter + 18),
                               centerY + Math.sin(angle) * (fixedGuideOuter + 18))
                    ctx.stroke()
                }
                ctx.globalAlpha = 1
            }
            Connections {
                target: Theme
                function onOutlineChanged() { guidesCanvas.requestPaint() }
                function onPrimaryChanged() { guidesCanvas.requestPaint() }
                function onSecondaryChanged() { guidesCanvas.requestPaint() }
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
                function onChildRevealActiveChanged() {
                    if (window.launcherState.childRevealActive)
                        guidesCanvas.startHierarchyPulse(false)
                }
                function onChildDismissActiveChanged() {
                    if (window.launcherState.childDismissActive)
                        guidesCanvas.startHierarchyPulse(true)
                }
            }
        }

        NumberAnimation {
            id: guideHierarchyPulse
            target: guidesCanvas
            property: "hierarchyPulseProgress"
            from: 0; to: 1
            duration: Config.motionDuration(Math.max(460, Config.animationMs * 2.6))
            easing.type: Easing.InOutCubic
            onRunningChanged: guidesCanvas.requestPaint()
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
            readonly property string selectedDescription: window.launcherState.currentItem
                ? (window.launcherState.currentItem.description || "") : ""
            readonly property string selectedParentLabel: {
                const stack = window.launcherState.navigationStack
                if (!stack.length) return ""
                const level = stack[stack.length - 1]
                if (!level || !level.items || level.selectedIndex < 0
                        || level.selectedIndex >= level.items.length) return ""
                const parent = level.items[level.selectedIndex]
                return parent && parent.label ? String(parent.label) : ""
            }
            readonly property string selectedCount: window.launcherState.items.length
                ? (window.launcherState.selectedIndex + 1) + "  /  " + window.launcherState.items.length
                : "0  /  0"
            property string displayedLabel: ""
            property string displayedDescription: ""
            property string displayedParentLabel: ""
            property string displayedCount: ""
            property string previousLabel: ""
            property string previousDescription: ""
            property string previousParentLabel: ""
            property string previousCount: ""
            property real incomingOpacity: 1
            property real outgoingOpacity: 0
            property real incomingOffset: 0
            property real outgoingOffset: 0
            readonly property real edgeMargin: 10
            width: 360
            height: width
            anchors.right: parent.right; anchors.bottom: parent.bottom
            anchors.rightMargin: edgeMargin; anchors.bottomMargin: edgeMargin
            opacity: window.launcherState.openingContentProgress
            scale: 0.92 + window.launcherState.openingContentProgress * 0.08
            Behavior on width { NumberAnimation { duration: Config.motionDuration(Math.max(300, Config.animationMs)); easing.type: Easing.OutCubic } }

            function queueInfoUpdate() { infoSyncTimer.restart() }
            function syncInfo() {
                const nextLabel = selectedLabel
                const nextDescription = selectedDescription
                const nextParentLabel = selectedParentLabel
                const nextCount = selectedCount
                if (nextLabel === displayedLabel && nextDescription === displayedDescription
                    && nextParentLabel === displayedParentLabel
                    && nextCount === displayedCount) return
                if (!displayedLabel || !window.launcherState.presenting) {
                    infoTransition.stop()
                    displayedLabel = nextLabel
                    displayedDescription = nextDescription
                    displayedParentLabel = nextParentLabel
                    displayedCount = nextCount
                    previousLabel = ""
                    previousDescription = ""
                    previousParentLabel = ""
                    previousCount = ""
                    incomingOpacity = 1
                    outgoingOpacity = 0
                    incomingOffset = 0
                    outgoingOffset = 0
                    return
                }
                const carriedOpacity = incomingOpacity
                const carriedOffset = incomingOffset
                infoTransition.stop()
                previousLabel = displayedLabel
                previousDescription = displayedDescription
                previousParentLabel = displayedParentLabel
                previousCount = displayedCount
                displayedLabel = nextLabel
                displayedDescription = nextDescription
                displayedParentLabel = nextParentLabel
                displayedCount = nextCount
                incomingOpacity = 0
                outgoingOpacity = carriedOpacity
                incomingOffset = 9
                outgoingOffset = carriedOffset
                infoTransition.restart()
            }

            Timer {
                id: infoSyncTimer
                interval: 0
                repeat: false
                onTriggered: hub.syncInfo()
            }

            Connections {
                target: window.launcherState
                function onSelectedIndexChanged() { hub.queueInfoUpdate() }
                function onItemsChanged() { hub.queueInfoUpdate() }
                function onPromptChanged() { hub.queueInfoUpdate() }
                function onNavigationStackChanged() { hub.queueInfoUpdate() }
                function onPresentingChanged() { hub.queueInfoUpdate() }
            }

            ParallelAnimation {
                id: infoTransition
                NumberAnimation {
                    target: hub; property: "incomingOpacity"; from: 0; to: 1
                    duration: Config.motionDuration(Math.max(180, Config.animationMs))
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: hub; property: "outgoingOpacity"; to: 0
                    duration: Config.motionDuration(Math.max(130, Config.animationMs * 0.75))
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: hub; property: "incomingOffset"; from: 9; to: 0
                    duration: Config.motionDuration(Math.max(210, Config.animationMs * 1.15))
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: hub; property: "outgoingOffset"; to: -6
                    duration: Config.motionDuration(Math.max(150, Config.animationMs * 0.85))
                    easing.type: Easing.InCubic
                }
                onFinished: {
                    hub.previousLabel = ""
                    hub.previousDescription = ""
                    hub.previousParentLabel = ""
                    hub.previousCount = ""
                }
            }

            Text {
                id: labelMeasure
                visible: false
                text: hub.selectedLabel
                font.pixelSize: 23; font.weight: Font.Medium
            }

            Item {
                anchors.fill: parent

                Text {
                    anchors.top: parent.top; anchors.topMargin: parent.height * 0.21
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 54; anchors.rightMargin: 54
                    height: 44
                    text: hub.previousParentLabel
                    visible: hub.previousParentLabel.length > 0
                        && hub.previousParentLabel !== hub.displayedParentLabel
                    opacity: hub.outgoingOpacity
                    transform: Translate { y: hub.outgoingOffset }
                    color: Qt.lighter(Theme.secondary, 1.18)
                    font.pixelSize: 17; font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    lineHeight: 0.9
                    lineHeightMode: Text.ProportionalHeight
                    elide: Text.ElideRight
                }

                Text {
                    anchors.top: parent.top; anchors.topMargin: parent.height * 0.21
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 54; anchors.rightMargin: 54
                    height: 44
                    text: hub.displayedParentLabel
                    visible: hub.displayedParentLabel.length > 0
                    opacity: hub.previousParentLabel === hub.displayedParentLabel
                        ? 1 : hub.incomingOpacity
                    transform: Translate {
                        y: hub.previousParentLabel === hub.displayedParentLabel
                            ? 0 : hub.incomingOffset
                    }
                    color: Qt.lighter(Theme.secondary, 1.18)
                    font.pixelSize: 17; font.weight: Font.DemiBold
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    lineHeight: 0.9
                    lineHeightMode: Text.ProportionalHeight
                    elide: Text.ElideRight
                }

                Text {
                    anchors.top: parent.top; anchors.topMargin: parent.height * 0.34
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 42; anchors.rightMargin: 42
                    height: font.pixelSize * 2.4
                    text: hub.previousLabel
                    opacity: hub.outgoingOpacity
                    transform: Translate { y: hub.outgoingOffset }
                    color: Qt.lighter(Theme.primary, 1.16); font.pixelSize: 23; font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideNone
                }

                Text {
                    anchors.top: parent.top; anchors.topMargin: parent.height * 0.34
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 42; anchors.rightMargin: 42
                    height: font.pixelSize * 2.4
                    text: hub.displayedLabel
                    opacity: hub.incomingOpacity
                    transform: Translate { y: hub.incomingOffset }
                    color: Qt.lighter(Theme.primary, 1.16); font.pixelSize: 23; font.weight: Font.Medium
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideNone
                }

                Text {
                    anchors.top: parent.top; anchors.topMargin: parent.height * 0.51
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: hub.previousCount
                    opacity: hub.outgoingOpacity
                    transform: Translate { y: hub.outgoingOffset }
                    color: Qt.lighter(Theme.tertiary, 1.10); font.pixelSize: 15; font.letterSpacing: 2
                }

                Text {
                    anchors.top: parent.top; anchors.topMargin: parent.height * 0.51
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: hub.displayedCount
                    opacity: hub.incomingOpacity
                    transform: Translate { y: hub.incomingOffset }
                    color: Qt.lighter(Theme.tertiary, 1.10); font.pixelSize: 15; font.letterSpacing: 2
                }

                Rectangle {
                    id: circularSearch
                    width: Math.min(440, parent.width - 88); height: 54; radius: 27
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.verticalCenterOffset: 58
                    color: Qt.rgba(Theme.controlSurface.r,
                                   Theme.controlSurface.g,
                                   Theme.controlSurface.b,
                                   Math.max(0.42, Math.min(0.58,
                                       Config.profileValue(window.launcherState.profile,
                                           "opacity", "inactive", Config.inactiveOpacity))))
                    border.color: window.launcherState.searchMode
                        ? Qt.lighter(Theme.primary, 1.16) : Theme.secondary
                    border.width: window.launcherState.searchMode ? 2 : 1
                    Text {
                        anchors.left: parent.left; anchors.leftMargin: 15; anchors.verticalCenter: parent.verticalCenter
                        text: "⌕"; color: Qt.lighter(Theme.primary, 1.16); font.pixelSize: 24
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
                            if (delta !== 0) window.launcherState.move(delta > 0 ? 1 : -1)
                            wheel.accepted = true
                        }
                    }
                }

                Text {
                    anchors.top: circularSearch.bottom; anchors.topMargin: 20
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 58; anchors.rightMargin: 58
                    text: hub.previousDescription
                    opacity: hub.outgoingOpacity
                    transform: Translate { y: hub.outgoingOffset }
                    color: Qt.lighter(Theme.secondary, 1.08); font.pixelSize: 15
                    horizontalAlignment: Text.AlignLeft
                    wrapMode: Text.WrapAnywhere
                    lineHeight: 1.15
                    lineHeightMode: Text.ProportionalHeight
                }

                Text {
                    anchors.top: circularSearch.bottom; anchors.topMargin: 20
                    anchors.left: parent.left; anchors.right: parent.right
                    anchors.leftMargin: 58; anchors.rightMargin: 58
                    text: hub.displayedDescription
                    opacity: hub.incomingOpacity
                    transform: Translate { y: hub.incomingOffset }
                    color: Qt.lighter(Theme.secondary, 1.08); font.pixelSize: 15
                    horizontalAlignment: Text.AlignLeft
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
            } else if (!window.launcherState.searchMode
                    && Config.matchesKey(event.key, Config.enterLevelKey)) {
                if (window.launcherState.enterLevel()) event.accepted = true
            } else if (!window.launcherState.searchMode
                    && Config.matchesKey(event.key, Config.backLevelKey)) {
                if (window.launcherState.goBack()) event.accepted = true
            } else if (event.key === Qt.Key_Up) {
                window.launcherState.move(1); event.accepted = true
            } else if (event.key === Qt.Key_Down) {
                window.launcherState.move(-1); event.accepted = true
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
