import QtQuick

Item {
    id: root
    required property var state
    property real radius: 545
    property real centerOffsetX: Config.centerOffsetX
    property real centerOffsetY: Config.centerOffsetY
    property real startAngle: 202
    property real endAngle: 263
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
    property var exitItems: []
    property int exitSelectedIndex: -1
    property var ancestorEnterItems: []
    property int ancestorEnterSelectedIndex: -1
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

    function captureReturnHandoff() {
        returnHandoffItems = levelItems
        returnHandoffSelectedIndex = selectedParent
    }

    function captureReturnOrigin() {
        const positions = []
        for (let i = 0; i < parentRepeater.count; ++i) {
            const item = parentRepeater.itemAt(i)
            if (!item) continue
            positions[i] = { centerX: item.x + item.width / 2, centerY: item.y + item.height / 2,
                width: item.width, height: item.height }
        }
        returnSourcePositions = positions
    }

    // Read the rendered position of the card that owns the current child
    // level. This deliberately follows the return animation; a captured
    // start position is already stale as soon as the parent begins moving.
    function selectedReturnCenter() {
        const index = displaySelectedParent
        const item = index >= 0 ? parentRepeater.itemAt(index) : null
        return item ? { centerX: item.x + item.width / 2, centerY: item.y + item.height / 2 } : null
    }

    function captureExitLayer() {
        exitItems = levelItems
        exitSelectedIndex = selectedParent
    }

    function captureAncestorEnterLayer() {
        const ancestorIndex = state.navigationStack.length - 2
        const ancestor = ancestorIndex >= 0 ? state.navigationStack[ancestorIndex] : null
        ancestorEnterItems = ancestor ? ancestor.items : []
        ancestorEnterSelectedIndex = ancestor ? ancestor.selectedIndex : -1
    }


    readonly property var level: state.navigationStack.length ? state.navigationStack[state.navigationStack.length - 1] : null
    readonly property var levelItems: level ? level.items : []
    readonly property int selectedParent: level ? level.selectedIndex : -1
    // Pre-create the ancestor cards while a deep level is open. This avoids
    // delegate/image creation work on the first frame of a deep-level back.
    readonly property var preparedAncestor: state.navigationStack.length > 1
        ? state.navigationStack[state.navigationStack.length - 2] : null
    readonly property var preparedAncestorItems: preparedAncestor ? preparedAncestor.items : []
    readonly property int preparedAncestorSelectedIndex: preparedAncestor ? preparedAncestor.selectedIndex : -1
    readonly property var ancestorDisplayItems: state.ancestorEnterHandoffActive
        ? ancestorEnterItems : preparedAncestorItems
    readonly property int ancestorDisplaySelectedIndex: state.ancestorEnterHandoffActive
        ? ancestorEnterSelectedIndex : preparedAncestorSelectedIndex
    readonly property var displayItems: state.parentReturnHandoffActive ? returnHandoffItems : levelItems
    readonly property int displaySelectedParent: state.parentReturnHandoffActive
        ? returnHandoffSelectedIndex : selectedParent
    readonly property var transferLevel: state.pendingMenu ? state.pendingMenu.previous : null
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
        const destinationAngle = count <= 1 ? (startAngle + endAngle) / 2
            : startAngle + index * (endAngle - startAngle) / Math.max(1, Math.min(7, count) - 1)
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
    visible: state.navigationStack.length > 0 || state.parentTransferActive || state.parentReturnHandoffActive

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
            readonly property real angle: root.ancestorDisplayItems.length <= 1 ? (root.startAngle + root.endAngle) / 2
                : root.startAngle + index * (root.endAngle - root.startAngle)
                    / Math.max(1, Math.min(7, root.ancestorDisplayItems.length) - 1)
            readonly property real endCenterX: root.width + root.centerOffsetX
                + Math.cos(angle * Math.PI / 180) * root.radius
            readonly property real endCenterY: root.height + root.centerOffsetY
                + Math.sin(angle * Math.PI / 180) * root.radius
            readonly property real startCenterX: root.width + width + 48
            readonly property real startCenterY: root.height + height + 48
            readonly property real progress: root.state.ancestorEnterHandoffActive
                ? 1 : root.state.ancestorEnterActive ? root.state.ancestorEnterProgress : 0
            modelData: root.ancestorDisplayItems[index]
            selected: index === root.ancestorDisplaySelectedIndex
            circular: true
            animateSelection: false
            animateOpacity: false
            animateFocus: false
            shown: true
            reveal: 1
            visualOpacity: progress
            cacheActive: true
            width: index === root.ancestorDisplaySelectedIndex ? root.targetItemSize : 88
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
            readonly property real angle: root.exitItems.length <= 1 ? (root.startAngle + root.endAngle) / 2
                : root.startAngle + index * (root.endAngle - root.startAngle)
                    / Math.max(1, Math.min(7, root.exitItems.length) - 1)
            readonly property real startCenterX: root.width + root.centerOffsetX
                + Math.cos(angle * Math.PI / 180) * root.radius
            readonly property real startCenterY: root.height + root.centerOffsetY
                + Math.sin(angle * Math.PI / 180) * root.radius
            readonly property real endCenterX: root.width + width + 48
            readonly property real endCenterY: root.height + height + 48
            readonly property real progress: root.state.parentExitProgress
            modelData: root.exitItems[index]
            selected: index === root.exitSelectedIndex
            circular: true
            animateSelection: false
            animateOpacity: false
            animateFocus: false
            shown: true
            reveal: 1
            visualOpacity: 1 - progress
            cacheActive: true
            width: index === root.exitSelectedIndex ? root.targetItemSize : 88
            height: width
            x: startCenterX + (endCenterX - startCenterX) * progress - width / 2
            y: startCenterY + (endCenterY - startCenterY) * progress - height / 2
            z: 28
        }
    }

    Repeater {
        model: root.state.parentTransferActive && root.transferLevel
            ? Math.min(7, root.transferLevel.items.length) : 0
        delegate: FanItem {
            required property int index
            readonly property int transferIndex: root.transferLevel ? root.transferLevel.selectedIndex : 0
            readonly property int itemCount: root.transferLevel ? root.transferLevel.items.length : 0
            readonly property real logicalOffset: {
                let offset = (index - root.capturedOuterRotationIndex) % itemCount
                if (itemCount > 1 && offset > itemCount / 2) offset -= itemCount
                if (itemCount > 1 && offset < -itemCount / 2) offset += itemCount
                return offset
            }
            readonly property real sourceAngle: root.capturedOuterSelectedAngle + logicalOffset * root.capturedOuterAngleStep
            readonly property real destinationAngle: itemCount <= 1
                ? (root.startAngle + root.endAngle) / 2
                : root.startAngle + index * (root.endAngle - root.startAngle)
                    / Math.max(1, Math.min(7, itemCount) - 1)
            readonly property var liveSource: root.transferSourcePositions[index]
            readonly property real startX: liveSource ? liveSource.centerX : root.width + root.capturedOuterCenterOffsetX
                + Math.cos(sourceAngle * Math.PI / 180) * root.capturedOuterRadius
            readonly property real startY: liveSource ? liveSource.centerY : root.height + root.capturedOuterCenterOffsetY
                + Math.sin(sourceAngle * Math.PI / 180) * root.capturedOuterRadius
            readonly property real endX: root.width + root.centerOffsetX
                + Math.cos(destinationAngle * Math.PI / 180) * root.radius
            readonly property real endY: root.height + root.centerOffsetY
                + Math.sin(destinationAngle * Math.PI / 180) * root.radius
            readonly property real finalSize: index === transferIndex ? root.targetItemSize : 88
            readonly property real sourceSize: liveSource ? Math.min(liveSource.width, liveSource.height)
                : Math.min(root.capturedOuterItemWidth, root.capturedOuterItemHeight)
            modelData: root.transferLevel.items[index]
            selected: index === transferIndex
            circular: true
            animateSelection: false
            animateOpacity: false
            animateFocus: false
            shown: true
            reveal: 1
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
            readonly property real angle: root.displayItems.length <= 1 ? (root.startAngle + root.endAngle) / 2
                : root.startAngle + index * (root.endAngle - root.startAngle) / Math.max(1, Math.min(7, root.displayItems.length) - 1)
            readonly property real ringCenterX: root.width + root.centerOffsetX + Math.cos(angle * Math.PI / 180) * root.radius
            readonly property real ringCenterY: root.height + root.centerOffsetY + Math.sin(angle * Math.PI / 180) * root.radius
            readonly property real returnOffset: root.capturedLogicalOffset(index,
                root.displayItems.length)
            readonly property real returnAngle: root.capturedOuterSelectedAngle
                + returnOffset * root.capturedOuterAngleStep
            readonly property var capturedTarget: root.displayItems.length === 6
                ? root.capturedOuterItemPositions[index] : null
            readonly property real returnCenterX: capturedTarget ? capturedTarget.centerX
                : root.width + root.capturedOuterCenterOffsetX
                    + Math.cos(returnAngle * Math.PI / 180) * root.capturedOuterRadius
            readonly property real returnCenterY: capturedTarget ? capturedTarget.centerY
                : root.height + root.capturedOuterCenterOffsetY
                    + Math.sin(returnAngle * Math.PI / 180) * root.capturedOuterRadius
            readonly property var liveReturnSource: root.returnSourcePositions[index]
            readonly property real returnStartCenterX: liveReturnSource ? liveReturnSource.centerX : ringCenterX
            readonly property real returnStartCenterY: liveReturnSource ? liveReturnSource.centerY : ringCenterY
            readonly property bool returning: root.state.parentReturnActive || root.state.parentReturnHandoffActive
            readonly property real returnProgress: root.state.parentReturnHandoffActive ? 1 : root.state.parentReturnProgress
            readonly property real centerX: returning
                ? returnStartCenterX + (returnCenterX - returnStartCenterX) * returnProgress : ringCenterX
            readonly property real centerY: returning
                ? returnStartCenterY + (returnCenterY - returnStartCenterY) * returnProgress : ringCenterY
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
            modelData: root.displayItems[index]
            selected: index === root.displaySelectedParent
            circular: true
            animateSelection: false
            // ParentRing changes model/selection while returning. Its visual
            // movement is already explicit in centerX/centerY/baseWidth;
            // implicit opacity or focus fades here cause a visible flicker.
            animateOpacity: false
            animateFocus: false
            shown: true
            reveal: root.state.presenting ? 1 : 0
            cacheActive: true
            width: baseWidth
            height: baseHeight
            x: centerX - width / 2
            y: centerY - height / 2
            // Keep the terminal return snapshot above freshly-created
            // FanLayout delegates until the handoff timer releases it. The
            // previous ordering let the two nearly-identical item layers
            // alternate during a scene-graph update, seen as a root flicker.
            z: (root.state.parentReturnActive || root.state.parentReturnHandoffActive)
                ? (selected ? 12 : 11) : (selected ? 9 : 3)
            onChosen: root.state.goBack()
            onScrolled: delta => root.state.move(delta > 0 ? -1 : 1)
        }
    }
}
