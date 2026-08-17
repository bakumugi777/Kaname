import QtQuick

Item {
    id: root
    required property var state
    property int visibleCount: Config.profileValue(state.profile, "geometry", "visibleItems", Config.visibleItems)
    property real configuredRadius: Config.profileValue(state.profile, "geometry", "radius", Config.radius)
    property real configuredStartAngle: Config.profileValue(state.profile, "geometry", "startAngle", Config.startAngle)
    property real configuredEndAngle: Config.profileValue(state.profile, "geometry", "endAngle", Config.endAngle)
    property real centerOffsetX: Config.profileValue(state.profile, "geometry", "centerOffsetX", Config.centerOffsetX)
    property real centerOffsetY: Config.profileValue(state.profile, "geometry", "centerOffsetY", Config.centerOffsetY)
    property real itemWidth: Config.profileValue(state.profile, "geometry", "itemWidth", Config.itemWidth)
    property real itemHeight: Config.profileValue(state.profile, "geometry", "itemHeight", Config.itemHeight)
    property real itemOpacity: Config.profileValue(state.profile, "opacity", "item", Config.itemOpacity)
    property real inactiveOpacity: Config.profileValue(state.profile, "opacity", "inactive", Config.inactiveOpacity)
    property real imageOpacity: Config.profileValue(state.profile, "opacity", "image", Config.imageOpacity)

    readonly property int slotCount: Math.max(1, Math.min(visibleCount, state.searchResults.length))
    readonly property int halfSlots: Math.floor(slotCount / 2)
    readonly property real centerAngle: (configuredStartAngle + configuredEndAngle) / 2
    readonly property real span: Math.max(75, Math.abs(configuredEndAngle - configuredStartAngle))
    readonly property real startAngle: centerAngle - span / 2
    readonly property real endAngle: centerAngle + span / 2
    readonly property real angleStep: span / Math.max(1, visibleCount - 1)
    readonly property real minimumChord: Math.max(itemWidth * 1.08, itemHeight * 1.35)
    readonly property real requiredRadius: angleStep > 0
        ? minimumChord / (2 * Math.sin(angleStep * Math.PI / 360)) : configuredRadius
    readonly property real radius: Math.max(760, configuredRadius, requiredRadius)
    readonly property real selectedAngle: (startAngle + endAngle) / 2

    function circularOffset(itemIndex) {
        const count = state.searchResults.length
        if (count <= 1) return 0
        if (count === 6) return itemIndex - (count - 1) / 2
        let offset = (itemIndex - state.searchRotationIndex) % count
        if (offset > count / 2) offset -= count
        if (offset < -count / 2) offset += count
        return offset
    }

    visible: state.searchMode || state.searchLeaving
    enabled: !state.searchContentAnimationActive

    Repeater {
        model: root.state.searchResults.length

        delegate: FanItem {
            id: resultItem
            required property int index
            readonly property real logicalOffset: root.circularOffset(index)
            property real animatedOffset: logicalOffset
            property bool snappingOffset: false
            onLogicalOffsetChanged: {
                const count = root.state.searchResults.length
                if (count > 1 && Math.abs(logicalOffset - animatedOffset) > count / 2) {
                    const destination = logicalOffset
                    snappingOffset = true
                    animatedOffset = destination + (destination < 0 ? -1 : 1)
                    Qt.callLater(() => {
                        snappingOffset = false
                        animatedOffset = destination
                    })
                } else {
                    animatedOffset = logicalOffset
                }
            }
            readonly property real boundedOffset: Math.max(-root.halfSlots,
                Math.min(root.halfSlots, animatedOffset))
            readonly property real angle: root.selectedAngle + boundedOffset * root.angleStep
            readonly property real angleRadians: angle * Math.PI / 180
            readonly property real targetX: root.width + root.centerOffsetX
                + Math.cos(angleRadians) * root.radius - width / 2
            readonly property real targetY: root.height + root.centerOffsetY
                + Math.sin(angleRadians) * root.radius - height / 2
            readonly property real edgeProgress: Math.max(0,
                Math.min(1, Math.abs(animatedOffset) - root.halfSlots))
            readonly property real edgeX: animatedOffset > 0 ? root.width + width + 24 : targetX
            readonly property real edgeY: animatedOffset < 0 ? root.height + height + 24 : targetY
            readonly property real placedX: targetX + (edgeX - targetX) * edgeProgress
            readonly property real placedY: targetY + (edgeY - targetY) * edgeProgress
            readonly property real presentation: root.state.searchPresentation
                * root.state.searchContentPresentation
            readonly property real inwardDistance: 12 * (1 - presentation)
            readonly property bool insideArc: Math.abs(animatedOffset) <= root.halfSlots + 1.05

            modelData: root.state.searchResults[index]
            selected: index === root.state.searchSelectedIndex
            shown: insideArc
            cacheActive: Math.abs(logicalOffset) <= root.halfSlots + Config.cacheRadius
            visualOpacity: presentation * root.state.openingContentProgress
            entranceScale: 0.96 + presentation * 0.04
            animateOpacity: false
            itemOpacity: root.itemOpacity
            inactiveOpacity: root.inactiveOpacity
            imageOpacity: root.imageOpacity
            circular: !modelData.isImage
            width: circular ? Math.min(root.itemWidth, root.itemHeight) : root.itemWidth
            height: circular ? width : root.itemHeight
            x: placedX - Math.cos(angleRadians) * inwardDistance
            y: placedY - Math.sin(angleRadians) * inwardDistance
            z: selected ? 20 : Math.max(10, 15 - Math.abs(animatedOffset))
            rotation: circular ? 0 : angle - root.selectedAngle

            onChosen: {
                if (root.state.navigationLocked()) return
                root.state.searchSelectedIndex = index
                root.state.accept()
            }
            onScrolled: delta => root.state.move(delta > 0 ? 1 : -1)
            onFocusRequested: root.state.focusFromPointer(index)

            Behavior on animatedOffset {
                enabled: !root.state.searchTransitionActive && !resultItem.snappingOffset
                NumberAnimation {
                    duration: Config.motionDuration(Math.max(260, Config.animationMs * 1.8))
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
