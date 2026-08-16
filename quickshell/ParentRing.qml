import QtQuick

Item {
    id: root
    required property var state
    property real radius: 545
    property real centerOffsetX: Config.centerOffsetX
    property real centerOffsetY: Config.centerOffsetY
    // LauncherWindow binds these to FanLayout so the retained parent level
    // occupies the same complete fan span as the root level.
    property real startAngle: 180
    property real endAngle: 270
    readonly property real targetItemSize: 116
    property real outerRadius: 760
    property real outerCenterOffsetX: Config.centerOffsetX
    property real outerCenterOffsetY: Config.centerOffsetY
    property real outerSelectedAngle: 232.5
    property real outerItemWidth: 104
    property real outerItemHeight: 104
    property real outerAngleStep: 15
    property int outerRotationIndex: 0
    property real capturedOuterRadius: 760
    property real capturedOuterCenterOffsetX: Config.centerOffsetX
    property real capturedOuterCenterOffsetY: Config.centerOffsetY
    property real capturedOuterSelectedAngle: 232.5
    property real capturedOuterItemWidth: 104
    property real capturedOuterItemHeight: 104
    property real capturedOuterAngleStep: 15
    property int capturedOuterRotationIndex: 0
    property var capturedOuterItemPositions: []
    property var returnHandoffItems: []
    property int returnHandoffSelectedIndex: -1
    property int returnHandoffRotationIndex: 0
    property var exitItems: []
    property int exitSelectedIndex: -1
    property int exitRotationIndex: 0
    property var ancestorEnterItems: []
    property int ancestorEnterSelectedIndex: -1
    property int ancestorEnterRotationIndex: 0
    property var transferSourcePositions: []
    property var returnSourcePositions: []

    function captureTransferOrigin(liveItemPositions) {
        capturedOuterRadius = outerRadius
        capturedOuterCenterOffsetX = outerCenterOffsetX
        capturedOuterCenterOffsetY = outerCenterOffsetY
        capturedOuterSelectedAngle = outerSelectedAngle
        capturedOuterItemWidth = outerItemWidth
        capturedOuterItemHeight = outerItemHeight
        capturedOuterAngleStep = outerAngleStep
        capturedOuterRotationIndex = outerRotationIndex
        transferSourcePositions = liveItemPositions || []
    }

    function outerGeometry() {
        return {
            radius: outerRadius,
            centerOffsetX: outerCenterOffsetX,
            centerOffsetY: outerCenterOffsetY,
            selectedAngle: outerSelectedAngle,
            itemWidth: outerItemWidth,
            itemHeight: outerItemHeight,
            angleStep: outerAngleStep,
            rotationIndex: outerRotationIndex,
            // captureTransferOrigin() runs immediately before this call, so
            // these are the real FanLayout endpoints for this exact level.
            itemPositions: transferSourcePositions
        }
    }

    function restoreReturnGeometry(geometry) {
        if (!geometry || geometry.radius === undefined) return
        capturedOuterRadius = geometry.radius
        capturedOuterCenterOffsetX = geometry.centerOffsetX
        capturedOuterCenterOffsetY = geometry.centerOffsetY
        capturedOuterSelectedAngle = geometry.selectedAngle
        capturedOuterItemWidth = geometry.itemWidth
        capturedOuterItemHeight = geometry.itemHeight
        capturedOuterAngleStep = geometry.angleStep
        capturedOuterRotationIndex = geometry.rotationIndex
        capturedOuterItemPositions = geometry.itemPositions || []
    }

    // Keep return endpoints identical to FanLayout.circularOffset(). Using
    // index - selectedIndex directly diverges at wrapped edges and whenever a
    // small fixed list keeps rotationIndex at zero.
    function capturedLogicalOffset(index, count) {
        if (count <= 1) return 0
        let offset = (index - capturedOuterRotationIndex) % count
        if (offset > count / 2) offset -= count
        if (offset < -count / 2) offset += count
        return offset
    }

    function itemIndexForSlot(slot, count, rotationIndex) {
        if (count < 7) return slot
        return ((rotationIndex + slot - 3) % count + count) % count
    }

    function slotForItemIndex(index, count, rotationIndex) {
        if (count < 7) return index
        let offset = (index - rotationIndex) % count
        if (offset > count / 2) offset -= count
        if (offset < -count / 2) offset += count
        return offset + 3
    }

    function transferEntries(count, sourceRotationIndex, destinationRotationIndex) {
        const entries = []
        if (count < 7) {
            for (let index = 0; index < count; ++index)
                entries.push({ itemIndex: index, sourceVisible: true, destinationVisible: true, wrapRole: "" })
            return entries
        }
        const rotationDelta = destinationRotationIndex - sourceRotationIndex
        if (count === 7 && Math.abs(rotationDelta) === 1) {
            const wrappingSlot = rotationDelta < 0 ? 6 : 0
            let wrappingIndex = -1
            for (let slot = 0; slot < 7; ++slot) {
                const itemIndex = itemIndexForSlot(slot, count, sourceRotationIndex)
                if (slot === wrappingSlot) {
                    wrappingIndex = itemIndex
                    entries.push({ itemIndex: itemIndex, sourceVisible: true,
                        destinationVisible: false, wrapRole: "out" })
                } else {
                    entries.push({ itemIndex: itemIndex, sourceVisible: true,
                        destinationVisible: true, wrapRole: "" })
                }
            }
            entries.push({ itemIndex: wrappingIndex, sourceVisible: false,
                destinationVisible: true, wrapRole: "in" })
            return entries
        }
        for (let slot = 0; slot < 7; ++slot) {
            entries.push({ itemIndex: itemIndexForSlot(slot, count, sourceRotationIndex),
                sourceVisible: true, destinationVisible: false, wrapRole: "" })
        }
        for (let slot = 0; slot < 7; ++slot) {
            const index = itemIndexForSlot(slot, count, destinationRotationIndex)
            let found = false
            for (let entry = 0; entry < entries.length; ++entry) {
                if (entries[entry].itemIndex === index) {
                    entries[entry].destinationVisible = true
                    found = true
                    break
                }
            }
            if (!found) entries.push({ itemIndex: index, sourceVisible: false,
                destinationVisible: true, wrapRole: "" })
        }
        return entries
    }

    function minimallyVisibleRotation(sourceRotationIndex, selectedIndex, count) {
        if (count < 7) return sourceRotationIndex
        let offset = (selectedIndex - sourceRotationIndex) % count
        if (offset > count / 2) offset -= count
        if (offset < -count / 2) offset += count
        if (offset > 2) return sourceRotationIndex + offset - 2
        if (offset < -2) return sourceRotationIndex + offset + 2
        return sourceRotationIndex
    }

    // One placement model covers every parent count. Small sets retain their
    // array order but use only the centred portion of the band. Large sets
    // expose the selected item and its three circular neighbours on each side.
    // Physical card sizes are included so the visible gaps remain even.
    function innerAngle(index, count, rotationIndex, selectedIndex) {
        if (count <= 1) return (startAngle + endAngle) / 2
        const visibleCount = Math.min(7, count)
        const slot = slotForItemIndex(index, count, rotationIndex)
        const selectedSlot = slotForItemIndex(selectedIndex, count, rotationIndex)
        const span = endAngle - startAngle
        const fullArcLength = Math.abs(span) * Math.PI / 180 * radius
        const usedArcLength = fullArcLength * (visibleCount - 1) / 6
        const normalSize = 88
        let occupiedIntervals = 0
        for (let interval = 0; interval < visibleCount - 1; ++interval) {
            const leftSize = interval === selectedSlot ? targetItemSize : normalSize
            const rightSize = interval + 1 === selectedSlot ? targetItemSize : normalSize
            occupiedIntervals += (leftSize + rightSize) / 2
        }
        const gap = Math.max(0, (usedArcLength - occupiedIntervals)
            / Math.max(1, visibleCount - 1))
        let distance = (fullArcLength - usedArcLength) / 2
        if (slot >= 0) {
            for (let interval = 0; interval < slot; ++interval) {
                const leftSize = interval === selectedSlot ? targetItemSize : normalSize
                const rightSize = interval + 1 === selectedSlot ? targetItemSize : normalSize
                distance += (leftSize + rightSize) / 2 + gap
            }
        } else {
            for (let interval = -1; interval >= slot; --interval) {
                const leftSize = interval === selectedSlot ? targetItemSize : normalSize
                const rightSize = interval + 1 === selectedSlot ? targetItemSize : normalSize
                distance -= (leftSize + rightSize) / 2 + gap
            }
        }
        return startAngle + (span < 0 ? -1 : 1)
            * distance / radius * 180 / Math.PI
    }

    function captureReturnHandoff() {
        returnHandoffItems = levelItems
        returnHandoffSelectedIndex = selectedParent
        returnHandoffRotationIndex = levelRotationIndex
    }

    function captureReturnOrigin() {
        const positions = []
        for (let i = 0; i < parentRepeater.count; ++i) {
            const item = parentRepeater.itemAt(i)
            if (!item) continue
            positions[item.itemIndex] = { centerX: item.x + item.width / 2, centerY: item.y + item.height / 2,
                width: item.width, height: item.height }
        }
        returnSourcePositions = positions
    }

    // Read the rendered position of the card that owns the current child
    // level. This deliberately follows the return animation; a captured
    // start position is already stale as soon as the parent begins moving.
    function selectedReturnCenter() {
        const index = displaySelectedParent
        const slot = index >= 0
            ? slotForItemIndex(index, displayItems.length, displayRotationIndex) : -1
        const item = slot >= 0 ? parentRepeater.itemAt(slot) : null
        return item ? { centerX: item.x + item.width / 2, centerY: item.y + item.height / 2 } : null
    }

    function captureExitLayer() {
        exitItems = levelItems
        exitSelectedIndex = selectedParent
        exitRotationIndex = levelRotationIndex
    }

    function captureAncestorEnterLayer() {
        const ancestorIndex = state.navigationStack.length - 2
        const ancestor = ancestorIndex >= 0 ? state.navigationStack[ancestorIndex] : null
        ancestorEnterItems = ancestor ? ancestor.items : []
        ancestorEnterSelectedIndex = ancestor ? ancestor.selectedIndex : -1
        ancestorEnterRotationIndex = ancestor && ancestor.geometry
            && ancestor.geometry.rotationIndex !== undefined
            ? ancestor.geometry.rotationIndex : ancestorEnterSelectedIndex
    }


    readonly property var level: state.navigationStack.length ? state.navigationStack[state.navigationStack.length - 1] : null
    readonly property var levelItems: level ? level.items : []
    readonly property int selectedParent: level ? level.selectedIndex : -1
    // The stack stores the minimally adjusted outer rotation: clipped edge
    // selections move just inside the fan while already-visible selections
    // keep their place.
    readonly property int levelRotationIndex: level && level.geometry
        && level.geometry.rotationIndex !== undefined
        ? level.geometry.rotationIndex : selectedParent
    // Pre-create the ancestor cards while a deep level is open. This avoids
    // delegate/image creation work on the first frame of a deep-level back.
    readonly property var preparedAncestor: state.navigationStack.length > 1
        ? state.navigationStack[state.navigationStack.length - 2] : null
    readonly property var preparedAncestorItems: preparedAncestor ? preparedAncestor.items : []
    readonly property int preparedAncestorSelectedIndex: preparedAncestor ? preparedAncestor.selectedIndex : -1
    readonly property int preparedAncestorRotationIndex: preparedAncestor && preparedAncestor.geometry
        && preparedAncestor.geometry.rotationIndex !== undefined
        ? preparedAncestor.geometry.rotationIndex : preparedAncestorSelectedIndex
    readonly property var ancestorDisplayItems: state.ancestorEnterHandoffActive
        ? ancestorEnterItems : preparedAncestorItems
    readonly property int ancestorDisplaySelectedIndex: state.ancestorEnterHandoffActive
        ? ancestorEnterSelectedIndex : preparedAncestorSelectedIndex
    readonly property int ancestorDisplayRotationIndex: state.ancestorEnterHandoffActive
        ? ancestorEnterRotationIndex : preparedAncestorRotationIndex
    readonly property var displayItems: state.parentReturnHandoffActive ? returnHandoffItems : levelItems
    readonly property int displaySelectedParent: state.parentReturnHandoffActive
        ? returnHandoffSelectedIndex : selectedParent
    readonly property int displayRotationIndex: state.parentReturnHandoffActive
        ? returnHandoffRotationIndex : levelRotationIndex
    readonly property var transferLevel: state.pendingMenu ? state.pendingMenu.previous : null
    // Compute this directly from the captured live outer rotation. Reading a
    // subsequently-added field from pendingMenu.previous.geometry does not
    // produce a QML change notification and left the transfer snapshot aimed
    // at its old centre fallback until the handoff frame.
    readonly property int transferDestinationRotationIndex: transferLevel
        ? minimallyVisibleRotation(capturedOuterRotationIndex,
            transferLevel.selectedIndex, transferLevel.items.length) : 0
    readonly property var transferDisplayEntries: transferLevel
        ? transferEntries(transferLevel.items.length, capturedOuterRotationIndex,
            transferDestinationRotationIndex) : []
    // Explicitly mirror the selected parent's return trajectory. Reading a
    // delegate's x/y through itemAt() does not create reliable QML binding
    // dependencies, so consumers need this progress-bound value instead.
    readonly property var liveReturnTarget: {
        const index = displaySelectedParent
        if (index < 0) return null
        const source = returnSourcePositions[index]
        const count = displayItems.length
        const angle = capturedOuterSelectedAngle
            + capturedLogicalOffset(index, count) * capturedOuterAngleStep
        const capturedTarget = count === 6 ? capturedOuterItemPositions[index] : null
        const startX = source ? source.centerX
            : width + centerOffsetX + Math.cos(angle * Math.PI / 180) * radius
        const startY = source ? source.centerY
            : height + centerOffsetY + Math.sin(angle * Math.PI / 180) * radius
        const endX = capturedTarget ? capturedTarget.centerX
            : width + capturedOuterCenterOffsetX
                + Math.cos(angle * Math.PI / 180) * capturedOuterRadius
        const endY = capturedTarget ? capturedTarget.centerY
            : height + capturedOuterCenterOffsetY
                + Math.sin(angle * Math.PI / 180) * capturedOuterRadius
        const progress = state.parentReturnHandoffActive ? 1
            : state.parentReturnActive ? state.parentReturnProgress : 0
        return {
            centerX: startX + (endX - startX) * progress,
            centerY: startY + (endY - startY) * progress
        }
    }
    // The selected card that opens a child level. Child cards use this as
    // their launch point so they visually unfold from their parent rather
    // than entering from an unrelated screen edge.
    readonly property var liveTransferOrigin: {
        const level = transferLevel
        if (!level || level.selectedIndex < 0) return null
        const index = level.selectedIndex
        const count = level.items.length
        const source = transferSourcePositions[index]
        const sourceAngle = capturedOuterSelectedAngle
        const destinationAngle = innerAngle(index, count,
            transferDestinationRotationIndex, level.selectedIndex)
        const startX = source ? source.centerX : width + capturedOuterCenterOffsetX
            + Math.cos(sourceAngle * Math.PI / 180) * capturedOuterRadius
        const startY = source ? source.centerY : height + capturedOuterCenterOffsetY
            + Math.sin(sourceAngle * Math.PI / 180) * capturedOuterRadius
        const endX = width + centerOffsetX + Math.cos(destinationAngle * Math.PI / 180) * radius
        const endY = height + centerOffsetY + Math.sin(destinationAngle * Math.PI / 180) * radius
        const progress = state.parentTransferActive ? state.parentTransferProgress : 1
        return {
            centerX: startX + (endX - startX) * progress,
            centerY: startY + (endY - startY) * progress
        }
    }
    visible: state.navigationStack.length > 0 || state.parentTransferActive
        || state.parentTransferHandoffActive || state.parentReturnHandoffActive
    // Parent and snapshot delegates do not use FanLayout's opening geometry.
    // Fade their common layer with the same content envelope so a whole-stack
    // Escape cannot leave inner-ring cards behind while the fan closes.
    opacity: state.openingContentProgress

    NumberAnimation {
        target: root.state
        property: "parentTransferProgress"
        from: 0; to: 1
        duration: Config.motionDuration(Math.max(360, Config.animationMs * 2))
        easing.type: Easing.InOutCubic
        running: root.state.parentTransferActive
        onFinished: root.state.finishParentTransfer()
    }

    NumberAnimation {
        target: root.state
        property: "ancestorEnterProgress"
        from: 0; to: 1
        duration: Config.motionDuration(Math.max(360, Config.animationMs * 2))
        // A return must visibly respond on the next frame. InOutCubic starts
        // almost flat and feels like an input delay on deep navigation.
        easing.type: Easing.OutCubic
        running: root.state.ancestorEnterActive
        onFinished: root.state.finishAncestorEnter()
    }

    // When returning from level 3 or deeper, the newly relevant ancestor
    // enters the two-level presentation from beyond the bottom-right edge.
    Repeater {
        model: root.state.ancestorEnterActive || root.state.ancestorEnterHandoffActive
            || root.state.navigationStack.length > 1
            ? Math.min(7, root.ancestorDisplayItems.length) : 0
        delegate: FanItem {
            required property int index
            readonly property int itemIndex: root.itemIndexForSlot(index,
                root.ancestorDisplayItems.length, root.ancestorDisplayRotationIndex)
            readonly property real angle: root.innerAngle(itemIndex,
                root.ancestorDisplayItems.length, root.ancestorDisplayRotationIndex,
                root.ancestorDisplaySelectedIndex)
            readonly property real endCenterX: root.width + root.centerOffsetX
                + Math.cos(angle * Math.PI / 180) * root.radius
            readonly property real endCenterY: root.height + root.centerOffsetY
                + Math.sin(angle * Math.PI / 180) * root.radius
            readonly property real startCenterX: root.width + width + 48
            readonly property real startCenterY: root.height + height + 48
            readonly property real progress: root.state.ancestorEnterHandoffActive
                ? 1 : root.state.ancestorEnterActive ? root.state.ancestorEnterProgress : 0
            modelData: root.ancestorDisplayItems[itemIndex]
            selected: itemIndex === root.ancestorDisplaySelectedIndex
            circular: true
            animateSelection: false
            animateOpacity: false
            animateFocus: false
            shown: true
            reveal: 1
            visualOpacity: progress
            cacheActive: true
            width: selected ? root.targetItemSize : 88
            height: width
            x: startCenterX + (endCenterX - startCenterX) * progress - width / 2
            y: startCenterY + (endCenterY - startCenterY) * progress - height / 2
            z: 28
        }
    }

    NumberAnimation {
        target: root.state
        property: "parentExitProgress"
        from: 0; to: 1
        duration: Config.motionDuration(Math.max(360, Config.animationMs * 2))
        easing.type: Easing.InOutCubic
        running: root.state.parentExitActive
        onFinished: root.state.finishParentExit()
    }

    // From the third level on, the previously visible inner parent is no
    // longer part of the two-level presentation. Move that snapshot beyond
    // the bottom-right corner while fading it, rather than removing it.
    Repeater {
        model: root.state.parentExitActive ? Math.min(7, root.exitItems.length) : 0
        delegate: FanItem {
            required property int index
            readonly property int itemIndex: root.itemIndexForSlot(index,
                root.exitItems.length, root.exitRotationIndex)
            readonly property real angle: root.innerAngle(itemIndex,
                root.exitItems.length, root.exitRotationIndex, root.exitSelectedIndex)
            readonly property real startCenterX: root.width + root.centerOffsetX
                + Math.cos(angle * Math.PI / 180) * root.radius
            readonly property real startCenterY: root.height + root.centerOffsetY
                + Math.sin(angle * Math.PI / 180) * root.radius
            readonly property real endCenterX: root.width + width + 48
            readonly property real endCenterY: root.height + height + 48
            readonly property real progress: root.state.parentExitProgress
            modelData: root.exitItems[itemIndex]
            selected: itemIndex === root.exitSelectedIndex
            circular: true
            animateSelection: false
            animateOpacity: false
            animateFocus: false
            shown: true
            reveal: 1
            visualOpacity: 1 - progress
            cacheActive: true
            width: selected ? root.targetItemSize : 88
            height: width
            x: startCenterX + (endCenterX - startCenterX) * progress - width / 2
            y: startCenterY + (endCenterY - startCenterY) * progress - height / 2
            z: 28
        }
    }

    Repeater {
        model: (root.state.parentTransferActive || root.state.parentTransferHandoffActive)
            && root.transferLevel
            ? root.transferDisplayEntries.length : 0
        delegate: FanItem {
            required property int index
            readonly property var transferEntry: root.transferDisplayEntries[index]
            readonly property int transferIndex: root.transferLevel ? root.transferLevel.selectedIndex : 0
            readonly property int itemCount: root.transferLevel ? root.transferLevel.items.length : 0
            readonly property int itemIndex: transferEntry.itemIndex
            readonly property real logicalOffset: {
                let offset = (itemIndex - root.capturedOuterRotationIndex) % itemCount
                if (itemCount > 1 && offset > itemCount / 2) offset -= itemCount
                if (itemCount > 1 && offset < -itemCount / 2) offset += itemCount
                return offset
            }
            readonly property real destinationOffset: {
                let offset = (itemIndex - root.transferDestinationRotationIndex) % itemCount
                if (itemCount > 1 && offset > itemCount / 2) offset -= itemCount
                if (itemCount > 1 && offset < -itemCount / 2) offset += itemCount
                return offset
            }
            readonly property bool sourceVisible: transferEntry.sourceVisible
            readonly property bool destinationVisible: transferEntry.destinationVisible
            readonly property int rotationDelta: root.transferDestinationRotationIndex
                - root.capturedOuterRotationIndex
            readonly property real syntheticSourceOffset: transferEntry.wrapRole === "in"
                ? (rotationDelta < 0 ? -4 : 4) : logicalOffset
            readonly property real syntheticDestinationOffset: transferEntry.wrapRole === "out"
                ? (rotationDelta < 0 ? 4 : -4) : destinationOffset
            readonly property real sourceAngle: root.capturedOuterSelectedAngle + logicalOffset * root.capturedOuterAngleStep
            readonly property real syntheticSourceAngle: root.capturedOuterSelectedAngle
                + syntheticSourceOffset * root.capturedOuterAngleStep
            readonly property real destinationAngle: transferEntry.wrapRole === "out"
                ? (root.startAngle + root.endAngle) / 2
                    + syntheticDestinationOffset / 6 * (root.endAngle - root.startAngle)
                : root.innerAngle(itemIndex, itemCount,
                    root.transferDestinationRotationIndex, transferIndex)
            readonly property var liveSource: root.transferSourcePositions[itemIndex]
            readonly property real startX: transferEntry.wrapRole !== "in" && liveSource
                ? liveSource.centerX : root.width + root.capturedOuterCenterOffsetX
                    + Math.cos(syntheticSourceAngle * Math.PI / 180) * root.capturedOuterRadius
            readonly property real startY: transferEntry.wrapRole !== "in" && liveSource
                ? liveSource.centerY : root.height + root.capturedOuterCenterOffsetY
                    + Math.sin(syntheticSourceAngle * Math.PI / 180) * root.capturedOuterRadius
            readonly property real endX: root.width + root.centerOffsetX
                + Math.cos(destinationAngle * Math.PI / 180) * root.radius
            readonly property real endY: root.height + root.centerOffsetY
                + Math.sin(destinationAngle * Math.PI / 180) * root.radius
            readonly property real finalSize: itemIndex === transferIndex ? root.targetItemSize : 88
            readonly property real sourceSize: liveSource ? Math.min(liveSource.width, liveSource.height)
                : Math.min(root.capturedOuterItemWidth, root.capturedOuterItemHeight)
            modelData: root.transferLevel.items[itemIndex]
            selected: itemIndex === transferIndex
            forceSelectionGlow: selected
            circular: true
            animateSelection: false
            animateOpacity: false
            animateFocus: false
            shown: true
            reveal: 1
            visualOpacity: sourceVisible && destinationVisible ? 1
                : sourceVisible ? 1 - root.state.parentTransferProgress
                : root.state.parentTransferProgress
            cacheActive: true
            // Transfer parents as circles throughout. A rectangular outer card
            // must not be stretched into the inner circular ring.
            width: sourceSize + (finalSize - sourceSize) * root.state.parentTransferProgress
            height: width
            x: startX + (endX - startX) * root.state.parentTransferProgress - width / 2
            y: startY + (endY - startY) * root.state.parentTransferProgress - height / 2
            z: selected ? 31 : 30
        }
    }

    Repeater {
        id: parentRepeater
        model: root.state.parentTransferActive
            || (root.state.ancestorEnterActive && root.state.navigationStack.length < 2)
            ? 0 : Math.min(7, root.displayItems.length)
        delegate: FanItem {
            required property int index
            readonly property int itemIndex: root.itemIndexForSlot(index,
                root.displayItems.length, root.displayRotationIndex)
            readonly property real angle: root.innerAngle(itemIndex,
                root.displayItems.length, root.displayRotationIndex,
                root.displaySelectedParent)
            readonly property real ringCenterX: root.width + root.centerOffsetX + Math.cos(angle * Math.PI / 180) * root.radius
            readonly property real ringCenterY: root.height + root.centerOffsetY + Math.sin(angle * Math.PI / 180) * root.radius
            readonly property real returnOffset: root.capturedLogicalOffset(itemIndex,
                root.displayItems.length)
            readonly property real returnAngle: root.capturedOuterSelectedAngle
                + returnOffset * root.capturedOuterAngleStep
            readonly property var capturedTarget: root.displayItems.length === 6
                ? root.capturedOuterItemPositions[itemIndex] : null
            readonly property real returnCenterX: capturedTarget ? capturedTarget.centerX
                : root.width + root.capturedOuterCenterOffsetX
                    + Math.cos(returnAngle * Math.PI / 180) * root.capturedOuterRadius
            readonly property real returnCenterY: capturedTarget ? capturedTarget.centerY
                : root.height + root.capturedOuterCenterOffsetY
                    + Math.sin(returnAngle * Math.PI / 180) * root.capturedOuterRadius
            readonly property var liveReturnSource: root.returnSourcePositions[itemIndex]
            readonly property real returnStartCenterX: liveReturnSource ? liveReturnSource.centerX : ringCenterX
            readonly property real returnStartCenterY: liveReturnSource ? liveReturnSource.centerY : ringCenterY
            readonly property bool returning: root.state.parentReturnActive || root.state.parentReturnHandoffActive
            readonly property real returnProgress: root.state.parentReturnHandoffActive ? 1 : root.state.parentReturnProgress
            readonly property real centerX: returning
                ? returnStartCenterX + (returnCenterX - returnStartCenterX) * returnProgress : ringCenterX
            readonly property real centerY: returning
                ? returnStartCenterY + (returnCenterY - returnStartCenterY) * returnProgress : ringCenterY
            // Whole-stack close mirrors FanLayout's angular collapse. Start
            // exactly at the live parent-ring position, then converge every
            // retained parent card onto the fan's center ray.
            readonly property real closingCenterX: root.width + root.centerOffsetX
                + Math.cos(root.outerSelectedAngle * Math.PI / 180) * root.radius
            readonly property real closingCenterY: root.height + root.centerOffsetY
                + Math.sin(root.outerSelectedAngle * Math.PI / 180) * root.radius
            readonly property real presentedCenterX: root.state.closing
                ? closingCenterX + (centerX - closingCenterX) * root.state.openingProgress
                : centerX
            readonly property real presentedCenterY: root.state.closing
                ? closingCenterY + (centerY - closingCenterY) * root.state.openingProgress
                : centerY
            readonly property real targetWidth: selected ? root.targetItemSize : 88
            readonly property real targetHeight: selected ? root.targetItemSize : 88
            // The return endpoint must be the exact base size of FanLayout.
            // FanItem applies the same selected/inactive scale in both layers,
            // so matching this base size also matches the rendered size.
            readonly property real returnBaseWidth: root.capturedOuterItemWidth
            readonly property real returnBaseHeight: root.capturedOuterItemHeight
            readonly property real baseWidth: returning
                ? targetWidth + (returnBaseWidth - targetWidth) * returnProgress : targetWidth
            readonly property real baseHeight: returning
                ? targetHeight + (returnBaseHeight - targetHeight) * returnProgress : targetHeight
            modelData: root.displayItems[itemIndex]
            selected: itemIndex === root.displaySelectedParent
            forceSelectionGlow: selected
            circular: true
            animateSelection: false
            // ParentRing changes model/selection while returning. Its visual
            // movement is already explicit in centerX/centerY/baseWidth;
            // implicit opacity or focus fades here cause a visible flicker.
            animateOpacity: false
            animateFocus: false
            // Construct and preload this persistent delegate underneath the
            // completed transfer snapshot, then expose it in one handoff.
            shown: !root.state.parentTransferHandoffActive
            reveal: root.state.presenting ? 1 : 0
            cacheActive: true
            width: baseWidth
            height: baseHeight
            x: presentedCenterX - width / 2
            y: presentedCenterY - height / 2
            // Keep the terminal return snapshot above freshly-created
            // FanLayout delegates until the handoff timer releases it. The
            // previous ordering let the two nearly-identical item layers
            // alternate during a scene-graph update, seen as a root flicker.
            z: (root.state.parentReturnActive || root.state.parentReturnHandoffActive)
                ? (selected ? 12 : 11) : (selected ? 9 : 3)
            onChosen: root.state.goBack()
            onScrolled: delta => root.state.move(delta > 0 ? 1 : -1)
        }
    }
}
