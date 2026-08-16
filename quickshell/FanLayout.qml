import QtQuick

Item {
    id: root
    required property var state
    // Captured by ParentRing at the instant a back navigation begins. These
    // are actual scene coordinates, not an inferred radius/angle.
    property var dismissTargets: []
    property int dismissTargetIndex: -1
    property var liveDismissTarget: null
    property real dismissBandRadius: 0
    property real dismissBandCenterOffsetX: 0
    property real dismissBandCenterOffsetY: 0
    property real dismissBandStartAngle: 0
    property real dismissBandEndAngle: 0
    property var childRevealOrigin: null
    property int visibleCount: Config.profileValue(state.profile, "geometry", "visibleItems", Config.visibleItems)
    property real configuredRadius: Config.profileValue(state.profile, "geometry", "radius", Config.radius)
    property real configuredStartAngle: Config.profileValue(state.profile, "geometry", "startAngle", Config.startAngle)
    property real configuredEndAngle: Config.profileValue(state.profile, "geometry", "endAngle", Config.endAngle)
    property real centerOffsetX: Config.profileValue(state.profile, "geometry", "centerOffsetX", Config.centerOffsetX)
    property real centerOffsetY: Config.profileValue(state.profile, "geometry", "centerOffsetY", Config.centerOffsetY)
    readonly property bool hierarchicalRoot: {
        if (state.navigationStack.length !== 0) return false
        for (let i = 0; i < state.items.length; ++i) {
            if (state.items[i] && state.items[i].type === "submenu") return true
        }
        return false
    }
    // Root category choosers use compact circular geometry regardless of who
    // supplied the hierarchy. Leaf-only dmenu input keeps its selected profile.
    readonly property bool menuRoot: state.navigationStack.length === 0
        && (state.mode === "menu" || state.mode === "applications" || hierarchicalRoot)
    property real configuredItemWidth: Config.profileValue(state.profile, "geometry", "itemWidth", Config.itemWidth)
    property real configuredItemHeight: Config.profileValue(state.profile, "geometry", "itemHeight", Config.itemHeight)
    readonly property real itemWidth: menuRoot ? 104 : configuredItemWidth
    readonly property real itemHeight: menuRoot ? 104 : configuredItemHeight
    property real itemOpacity: Config.profileValue(state.profile, "opacity", "item", Config.itemOpacity)
    property real inactiveOpacity: Config.profileValue(state.profile, "opacity", "inactive", Config.inactiveOpacity)
    property real imageOpacity: Config.profileValue(state.profile, "opacity", "image", Config.imageOpacity)

    readonly property int slotCount: Math.max(1, Math.min(visibleCount, state.items.length))
    readonly property int halfSlots: Math.floor(slotCount / 2)
    readonly property real configuredCenterAngle: (configuredStartAngle + configuredEndAngle) / 2
    readonly property real configuredSpan: Math.abs(configuredEndAngle - configuredStartAngle)
    readonly property real effectiveSpan: Math.max(75, configuredSpan)
    readonly property real startAngle: configuredCenterAngle - effectiveSpan / 2
    readonly property real endAngle: configuredCenterAngle + effectiveSpan / 2
    readonly property bool compactSixRoot: menuRoot && state.items.length === 6
    // Six fixed entries are centred on half-slots (-2.5 ... +2.5). Using the
    // normal seven-slot step pushes the lower endpoint too close to 180° and
    // clips that card at the bottom edge. Give six entries one extra virtual
    // interval so they stay centred but fit inside the same fan. Every motion
    // path and captured return geometry consumes this single angleStep value.
    readonly property real angleStep: compactSixRoot
        ? effectiveSpan / Math.max(1, visibleCount)
        : effectiveSpan / Math.max(1, visibleCount - 1)
    readonly property real minimumChord: Math.max(itemWidth * 1.08, itemHeight * 1.35)
    readonly property real requiredRadius: compactSixRoot ? 540
        : angleStep > 0 ? minimumChord / (2 * Math.sin(angleStep * Math.PI / 360)) : configuredRadius
    readonly property real radius: Math.max(menuRoot ? 540 : 760, menuRoot ? 540 : configuredRadius, requiredRadius)
    readonly property real selectedAngle: (startAngle + endAngle) / 2
    // Do not let the temporary setItems(…)->saved selection restoration at
    // the end of a back navigation look like a new item entrance.
    readonly property bool returningToParent: state.parentReturnActive
        || state.parentReturnHandoffActive || state.parentReturnSettleActive

    function circularOffset(itemIndex) {
        const count = state.items.length
        if (count <= 1) return 0
        // Six entries all fit in the fan. Keep their order and positions
        // stable; rotating an even-sized circular set makes the opposite card
        // switch sides at the 6 -> 1 boundary and is visually ambiguous.
        if (count === 6) return itemIndex - (count - 1) / 2
        // rotationIndex is deliberately unbounded so a complete loop remains
        // a sequence of one-slot moves. Reduce it only for placement.
        let offset = (itemIndex - state.rotationIndex) % count
        if (offset > count / 2) offset -= count
        if (offset < -count / 2) offset += count
        return offset
    }

    function liveItemPositions() {
        const positions = []
        for (let i = 0; i < repeater.count; ++i) {
            const item = repeater.itemAt(i)
            if (!item) continue
            positions[i] = { centerX: item.x + item.width / 2, centerY: item.y + item.height / 2,
                width: item.width, height: item.height }
        }
        return positions
    }

    Repeater {
        id: repeater
        model: root.state.items.length

        delegate: FanItem {
            id: fanItem
            required property int index
            readonly property real logicalOffset: root.circularOffset(index)
            property real animatedOffset: logicalOffset
            property bool snappingOffset: false
            // A normalized offset wraps from one end of the circular list to
            // the other. With seven entries both ends are still partly on
            // screen, so snapping -3 -> +3 makes a card appear to stick to an
            // edge. Place it one slot beyond the opposite edge and start its
            // entrance in the same event turn as every other card's movement.
            onLogicalOffsetChanged: {
                const count = root.state.items.length
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
            readonly property real angle: root.selectedAngle + animatedOffset * root.angleStep
            readonly property real boundedOffset: Math.max(-root.halfSlots, Math.min(root.halfSlots, animatedOffset))
            readonly property real boundedAngle: root.selectedAngle + boundedOffset * root.angleStep
            readonly property real arcX: root.width + root.centerOffsetX + Math.cos(boundedAngle * Math.PI / 180) * root.radius - width / 2
            readonly property real arcY: root.height + root.centerOffsetY + Math.sin(boundedAngle * Math.PI / 180) * root.radius - height / 2
            readonly property real edgeProgress: Math.max(0, Math.min(1, Math.abs(animatedOffset) - root.halfSlots))
            readonly property real exitX: animatedOffset > 0 ? root.width + width + 24 : arcX
            readonly property real exitY: animatedOffset < 0 ? root.height + height + 24 : arcY
            readonly property real targetX: arcX + (exitX - arcX) * edgeProgress
            readonly property real targetY: arcY + (exitY - arcY) * edgeProgress
            readonly property real normalEntranceX: root.width + width + 24
            readonly property real normalEntranceY: root.height + height + 24
            // Child items unfold from the selected parent card. Their final
            // radial slot is never recalculated while the reveal runs.
            readonly property real childEntranceX: root.childRevealOrigin
                ? root.childRevealOrigin.centerX - width / 2 : root.width + width + 48
            readonly property real childEntranceY: root.childRevealOrigin
                ? root.childRevealOrigin.centerY - height / 2 : targetY
            readonly property real revealStartX: root.state.childRevealActive ? childEntranceX : normalEntranceX
            readonly property real revealStartY: root.state.childRevealActive ? childEntranceY : normalEntranceY
            readonly property bool insideArc: Math.abs(animatedOffset) <= root.halfSlots + 1.05
            // At launcher startup, cards spread out from the same center ray
            // as the opening fan. Once opened, this resolves to targetX/Y and
            // does not affect scrolling or hierarchy animations.
            readonly property real openingCenterX: root.width + root.centerOffsetX
                + Math.cos(root.selectedAngle * Math.PI / 180) * root.radius - width / 2
            readonly property real openingCenterY: root.height + root.centerOffsetY
                + Math.sin(root.selectedAngle * Math.PI / 180) * root.radius - height / 2
            readonly property real revealedX: revealStartX + (targetX - revealStartX) * reveal
            readonly property real revealedY: revealStartY + (targetY - revealStartY) * reveal
            // A child level is absorbed by the parent *band* on back. Unlike
            // cards, this band is fixed while the parent cards animate away,
            // making it a stable target at every hierarchy depth.
            readonly property real normalX: openingCenterX + (revealedX - openingCenterX) * root.state.openingProgress
            readonly property real normalY: openingCenterY + (revealedY - openingCenterY) * root.state.openingProgress
            readonly property real dismissProgress: root.state.childDismissActive
                ? 1 - root.state.childDismissProgress : 0
            readonly property bool deepDismiss: root.state.navigationStack.length > 1
            readonly property bool hasDismissBand: root.dismissBandRadius > 0
            readonly property real dismissBandAngle: Math.max(root.dismissBandStartAngle,
                Math.min(root.dismissBandEndAngle, boundedAngle))
            readonly property var dismissTarget: root.liveDismissTarget
                || (root.dismissTargetIndex >= 0 && root.dismissTargetIndex < root.dismissTargets.length
                    ? root.dismissTargets[root.dismissTargetIndex] : null)
            readonly property real fallbackDismissDistance: Math.max(root.itemHeight * 1.25,
                root.radius - 545)
            readonly property real dismissX: dismissTarget
                ? dismissTarget.centerX - width / 2
                : hasDismissBand
                ? root.width + root.dismissBandCenterOffsetX
                    + Math.cos(dismissBandAngle * Math.PI / 180) * root.dismissBandRadius - width / 2
                : normalX - Math.cos(boundedAngle * Math.PI / 180) * fallbackDismissDistance
            readonly property real dismissY: dismissTarget
                ? dismissTarget.centerY - height / 2
                : hasDismissBand
                ? root.height + root.dismissBandCenterOffsetY
                    + Math.sin(dismissBandAngle * Math.PI / 180) * root.dismissBandRadius - height / 2
                : normalY - Math.sin(boundedAngle * Math.PI / 180) * fallbackDismissDistance

            modelData: root.state.items[index]
            selected: index === root.state.selectedIndex
            // During a parent-return handoff this delegate is underneath the
            // snapshot layer. Keep both fully lit so releasing the snapshot
            // cannot expose a dark frame.
            forceSelectionGlow: selected && root.returningToParent
            // The return snapshot owns the final 80ms handoff. Rendering the
            // newly-created translucent card underneath it composites the two
            // surfaces and makes root items flash darker before settling.
            shown: insideArc && !root.state.parentReturnHandoffActive
            cacheActive: Math.abs(logicalOffset) <= root.halfSlots + Config.cacheRadius
            // Initial presentation is a stationary soft fade/scale. Child
            // navigation keeps its own horizontal reveal animation below.
            reveal: root.state.childRevealActive ? root.state.childRevealProgress : 1
            // At deep levels, keep children solid until they physically reach
            // the parent band, then remove that layer in finishChildDismiss().
            // Fading while travelling made the cards appear to disappear
            // before being absorbed. The root return retains its soft fade.
            visualOpacity: root.state.childLayerHidden ? 0
                : root.state.childDismissActive
                    ? (deepDismiss ? 1 : root.state.childDismissProgress) : 1
                * root.state.openingContentProgress
            entranceScale: 0.90 + root.state.openingContentProgress * 0.10
            // Enter the parent card rather than merely overlap its edge.
            exitScale: 1 - dismissProgress * 0.72
            // Returning to a parent replaces the hidden child model with the
            // already-visible parent model. Do not treat that handoff as a
            // fresh item entrance (which otherwise animates opacity from 0).
            animateOpacity: !root.state.childRevealActive && !root.state.childDismissActive
                && !root.returningToParent
            animateSelection: !root.returningToParent
            animateFocus: !root.returningToParent
            itemOpacity: root.itemOpacity
            inactiveOpacity: root.inactiveOpacity
            imageOpacity: root.imageOpacity
            // Commands, folders, and plain dmenu entries share the circular
            // launcher language. Actual img: / image candidates stay as
            // rectangular thumbnail cards so previews retain their aspect and
            // readability.
            circular: !modelData.isImage
            // Circular items have a fixed square footprint. Labels never
            // affect geometry; only real image candidates use the configured
            // rectangular thumbnail dimensions.
            width: circular ? Math.min(root.itemWidth, root.itemHeight) : root.itemWidth
            height: circular ? width : root.itemHeight
            x: normalX + (dismissX - normalX) * dismissProgress
            y: normalY + (dismissY - normalY) * dismissProgress
            z: selected ? 10 : Math.max(0, 5 - Math.abs(animatedOffset))
            rotation: circular ? 0 : boundedAngle - root.selectedAngle

            onChosen: { root.state.selectedIndex = index; root.state.accept() }
            onScrolled: delta => root.state.move(delta > 0 ? 1 : -1)
            onFocusRequested: root.state.focusFromPointer(index)

            Behavior on animatedOffset {
                enabled: !root.returningToParent && !fanItem.snappingOffset
                NumberAnimation {
                    duration: Config.motionDuration(Math.max(260, Config.animationMs * 1.8))
                    easing.type: Easing.OutCubic
                }
            }
            Behavior on reveal {
                enabled: !root.state.childRevealActive && !root.state.childDismissActive
                    && !root.returningToParent
                NumberAnimation {
                    duration: Config.motionDuration(Math.max(300, Config.animationMs * 2) + Math.min(index, Config.visibleItems) * 22)
                    easing.type: Easing.OutCubic
                }
            }
        }
    }
}
