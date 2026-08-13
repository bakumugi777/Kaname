import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property bool active: false
    property bool presenting: false
    property bool closing: false
    // Startup-only sweep for opening the fan from its center line.
    property real openingProgress: 1
    // Content follows the fan sweep: it begins shortly after the center ray
    // appears and reaches full opacity when the fan reaches its final span.
    readonly property real openingContentProgress: {
        const progress = Math.max(0, Math.min(1, (openingProgress - 0.12) / 0.88))
        return progress * progress * (3 - 2 * progress)
    }
    property string requestId: ""
    property string resultPath: ""
    property string prompt: ""
    property string profile: "default"
    property string screenName: Config.defaultScreen
    property string mode: "dmenu"
    property string outputMode: "raw"
    property var allItems: []
    property var items: []
    property int selectedIndex: 0
    property int rotationIndex: 0
    readonly property var currentItem: items.length && selectedIndex >= 0 && selectedIndex < items.length ? items[selectedIndex] : null
    property int scrollIndex: 0
    property bool searchMode: false
    property string query: ""
    property int savedIndex: 0
    property int visibleItems: Config.visibleItems
    property int closeAnimationMs: Config.motionDuration(Math.max(300, Config.animationMs * 2))
    property var navigationStack: []
    property bool providerAwaiting: false
    property bool parentTransferActive: false
    property real parentTransferProgress: 0
    property bool parentExitActive: false
    property real parentExitProgress: 1
    property bool ancestorEnterActive: false
    property real ancestorEnterProgress: 1
    property bool ancestorEnterHandoffActive: false
    property var pendingMenu: null
    property bool menuEntryPending: false
    // Transfer snapshots the live item coordinates, so no settle delay is
    // needed after keyboard/pointer selection.
    property int selectionSettleMs: 0
    property bool childRevealActive: false
    property real childRevealProgress: 1
    property bool childDismissActive: false
    property real childDismissProgress: 1
    property bool childLayerHidden: false
    property bool bandCollapseActive: false
    property real bandCollapseProgress: 1
    property var pendingBack: null
    property bool parentReturnActive: false
    property real parentReturnProgress: 1
    // Keeps the return-ring paint alive while FanLayout creates the restored
    // parent delegates underneath it.
    property bool parentReturnHandoffActive: false
    // Remains true for one event-loop turn after the handoff. This prevents
    // FanItem's opacity Behavior from interpreting the newly exposed root
    // delegates as a fresh launcher entrance.
    property bool parentReturnSettleActive: false
    signal commandRequested(var command, string workingDirectory)
    signal applicationsRequested()
    signal providerRequested(var item)
    signal parentTransferStarting()
    signal parentReturnStarting(var geometry)
    signal parentExitStarting()
    signal ancestorEnterSnapshotRequested()
    signal parentReturnHandoffStarting()

    property FileView resultFile: FileView { atomicWrites: true }

    function parseLineCandidates(candidateText, request) {
        const lines = candidateText.split("\n")
        const parsed = []
        for (let i = 0; i < lines.length; ++i) {
            if (lines[i].length === 0) continue
            const raw = lines[i]
            const isImage = raw.startsWith("img:")
            const path = isImage ? raw.substring(4) : ""
            const slash = path.lastIndexOf("/")
            parsed.push({
                id: request + "-" + i,
                value: raw,
                raw: raw,
                label: isImage ? path.substring(slash + 1) : raw,
                description: isImage ? path : "",
                image: path,
                isImage: isImage,
                searchText: (raw + " " + path).toLowerCase()
            })
        }
        return parsed
    }

    function open(request, candidateText, promptText, responsePath, requestedProfile, inputFormat, requestedOutputMode, requestedScreen) {
        menuEntryTimer.stop()
        menuEntryPending = false
        childRevealActive = false
        childRevealProgress = 1
        childDismissActive = false
        childDismissProgress = 1
        childLayerHidden = false
        bandCollapseActive = false
        bandCollapseProgress = 1
        parentReturnActive = false
        parentReturnProgress = 1
        parentReturnHandoffActive = false
        parentReturnSettleActive = false
        pendingBack = null
        parentTransferActive = false
        parentTransferProgress = 0
        parentExitActive = false
        parentExitProgress = 1
        ancestorEnterActive = false
        ancestorEnterProgress = 1
        ancestorEnterHandoffActive = false
        pendingMenu = null
        requestId = request
        resultPath = responsePath
        prompt = promptText
        profile = requestedProfile || "default"
        screenName = requestedScreen || Config.defaultScreen
        mode = "dmenu"
        outputMode = requestedOutputMode || "raw"
        navigationStack = []
        const lines = candidateText.split("\n")
        const parsed = []
        for (let i = 0; i < lines.length; ++i) {
            if (lines[i].length === 0) continue
            const raw = lines[i]
            if (inputFormat === "jsonl") {
                let value
                try { value = JSON.parse(raw) }
                catch (failure) {
                    resultFile.path = resultPath
                    resultFile.setText("error\nline " + (i + 1) + ": " + failure + "\n")
                    return
                }
                const label = value.label || value.value || value.id
                if (label === undefined) {
                    resultFile.path = resultPath
                    resultFile.setText("error\nline " + (i + 1) + ": label, value, or id is required\n")
                    return
                }
                parsed.push({
                    id: value.id !== undefined ? String(value.id) : request + "-" + i,
                    value: value.value !== undefined ? String(value.value) : raw,
                    raw: raw,
                    json: value,
                    label: String(label),
                    description: value.description || "",
                    icon: value.icon || "",
                    image: value.image || "",
                    isImage: !!value.image,
                    key: value.key || "",
                    disabled: value.disabled === true,
                    searchText: (label + " " + (value.description || "") + " " + (value.image || "") + " " + (value.value || "") + " " + (Array.isArray(value.keywords) ? value.keywords.join(" ") : "")).toLowerCase()
                })
            } else {
                const simpleItems = parseLineCandidates(raw, request + "-" + i)
                for (let simpleIndex = 0; simpleIndex < simpleItems.length; ++simpleIndex)
                    parsed.push(simpleItems[simpleIndex])
            }
        }
        allItems = parsed
        items = parsed
        selectedIndex = 0
        rotationIndex = 0
        scrollIndex = Math.floor(Math.min(visibleItems, parsed.length) / 2)
        query = ""
        searchMode = false
        show()
    }

    function openWallpaper(request, imageText, videoText, promptText, responsePath, requestedProfile, requestedOutputMode, requestedScreen) {
        menuEntryTimer.stop()
        menuEntryPending = false
        childRevealActive = false
        childRevealProgress = 1
        childDismissActive = false
        childDismissProgress = 1
        childLayerHidden = false
        bandCollapseActive = false
        bandCollapseProgress = 1
        parentReturnActive = false
        parentReturnProgress = 1
        parentReturnHandoffActive = false
        parentReturnSettleActive = false
        pendingBack = null
        parentTransferActive = false
        parentTransferProgress = 0
        parentExitActive = false
        parentExitProgress = 1
        ancestorEnterActive = false
        ancestorEnterProgress = 1
        ancestorEnterHandoffActive = false
        pendingMenu = null
        requestId = request
        resultPath = responsePath
        prompt = promptText || "Select Wallpaper"
        profile = requestedProfile || "wallpaper"
        screenName = requestedScreen || Config.defaultScreen
        mode = "wallpaper"
        outputMode = requestedOutputMode || "raw"
        navigationStack = []
        const imageItems = parseLineCandidates(imageText, request + "-image")
        const videoItems = parseLineCandidates(videoText, request + "-video")
        const roots = []
        if (imageItems.length) roots.push({
            id: "wallpaper-image", type: "submenu", label: "Image",
            description: imageItems.length + " images", icon: "image-x-generic",
            fallbackVisual: "image",
            image: "", isImage: false, key: "i", children: imageItems,
            searchText: "image wallpaper"
        })
        if (videoItems.length) roots.push({
            id: "wallpaper-video", type: "submenu", label: "Video",
            description: videoItems.length + " videos", icon: "video-x-generic",
            fallbackVisual: "video",
            image: "", isImage: false, key: "v", children: videoItems,
            searchText: "video wallpaper"
        })
        allItems = roots
        items = roots
        selectedIndex = 0
        rotationIndex = 0
        scrollIndex = 0
        query = ""
        searchMode = false
        show()
    }

    function openItems(newMode, newPrompt, newItems, requestedScreen) {
        menuEntryTimer.stop()
        menuEntryPending = false
        childRevealActive = false
        childRevealProgress = 1
        childDismissActive = false
        childDismissProgress = 1
        childLayerHidden = false
        bandCollapseActive = false
        bandCollapseProgress = 1
        parentReturnActive = false
        parentReturnProgress = 1
        parentReturnHandoffActive = false
        parentReturnSettleActive = false
        pendingBack = null
        parentTransferActive = false
        parentTransferProgress = 0
        parentExitActive = false
        parentExitProgress = 1
        ancestorEnterActive = false
        ancestorEnterProgress = 1
        ancestorEnterHandoffActive = false
        pendingMenu = null
        mode = newMode
        requestId = ""
        resultPath = ""
        profile = newMode
        screenName = requestedScreen || Config.defaultScreen
        prompt = newPrompt
        navigationStack = []
        setItems(newItems)
        query = ""
        searchMode = false
        show()
    }

    function show() {
        closeTimer.stop()
        closing = false
        active = true
        presenting = false
        openingProgress = 0
        revealTimer.restart()
    }

    function beginClose() {
        if (!active || closing) return
        // Keep the window presented while the angular sweep reverses. It is
        // hidden only after the fan, cards, and hub have reached the center.
        closing = true
        closeTimer.interval = closeAnimationMs
        closeTimer.restart()
    }

    function setItems(newItems) {
        allItems = newItems || []
        items = allItems
        selectedIndex = 0
        rotationIndex = 0
        scrollIndex = Math.floor(Math.min(visibleItems, items.length) / 2)
    }

    function enterMenu(newPrompt, newItems) {
        if (parentTransferActive || menuEntryPending) return
        pendingMenu = {
            prompt: newPrompt,
            items: newItems,
            previous: { prompt: prompt, items: allItems, selectedIndex: selectedIndex }
        }
        // Let FanItem finish its selection-scale animation before any item is
        // replaced by the parent-transfer layer.
        menuEntryPending = true
        menuEntryTimer.restart()
    }

    function captureNavigationGeometry(geometry) {
        // Called immediately before the current level is pushed. Keeping this
        // with the stack entry lets a deep return restore the actual target
        // level, rather than whichever level was most recently animated.
        if (pendingMenu && pendingMenu.previous && geometry)
            pendingMenu.previous.geometry = geometry
    }

    function startParentTransfer() {
        if (!menuEntryPending || !pendingMenu) return
        menuEntryPending = false
        const target = pendingMenu
        // Let the visual layer snapshot the current outer geometry before the
        // child model changes FanLayout's radius and item dimensions.
        if (navigationStack.length > 0) {
            parentExitStarting()
            parentExitProgress = 0
            parentExitActive = true
        }
        parentTransferStarting()
        parentTransferProgress = 0
        childRevealProgress = 0
        parentTransferActive = true
        childRevealActive = true
        // Keep the previous layer in pendingMenu for the transfer overlay, but
        // install the child layer now so all three animations start together.
        navigationStack = navigationStack.concat([target.previous])
        prompt = target.prompt
        setItems(target.items)
        query = ""
        searchMode = false
    }

    function finishParentTransfer() {
        if (!parentTransferActive || !pendingMenu) return
        parentTransferActive = false
        parentTransferProgress = 1
        pendingMenu = null
    }

    function finishParentExit() {
        parentExitActive = false
        parentExitProgress = 1
    }

    function finishAncestorEnter() {
        // Snapshot only after the animation has finished. The input path uses
        // the already prepared ancestor delegates without any model rebinding.
        ancestorEnterSnapshotRequested()
        ancestorEnterActive = false
        ancestorEnterProgress = 1
        // Keep the completed incoming ancestor painted while the normal
        // ParentRing replaces its model after navigationStack is popped.
        ancestorEnterHandoffActive = true
        completeBackAnimationIfReady()
    }

    function finishChildReveal() {
        childRevealActive = false
        childRevealProgress = 1
    }

    function finishChildDismiss() {
        if (!childDismissActive || !pendingBack) return
        // Set the persistent hidden state before ending the fade state.  This
        // prevents one evaluation frame in which the child layer can resolve
        // back to full opacity between the two phases.
        childLayerHidden = true
        childDismissActive = false
        childDismissProgress = 0
        completeBackAnimationIfReady()
    }

    function finishBandCollapse() {
        if (!bandCollapseActive || !pendingBack) return
        bandCollapseActive = false
        bandCollapseProgress = 0
        completeBackAnimationIfReady()
    }

    function finishParentReturn() {
        if (!parentReturnActive || !pendingBack) return
        parentReturnActive = false
        parentReturnProgress = 1
        completeBackAnimationIfReady()
    }

    function completeBackAnimationIfReady() {
        if (!pendingBack || childDismissActive || bandCollapseActive || parentReturnActive || ancestorEnterActive) return
        const previous = pendingBack
        // Snapshot the terminal ring before replacing its model.  FanLayout
        // then gets a frame to construct the restored parent cards beneath it.
        parentReturnHandoffStarting()
        // This must be enabled *before* setItems().  Otherwise newly-created
        // parent delegates briefly see their normal Behaviors enabled and
        // play a second, display-like animation after reaching the endpoint.
        parentReturnSettleActive = true
        parentReturnHandoffActive = true
        providerAwaiting = false
        navigationStack = navigationStack.slice(0, -1)
        prompt = previous.prompt
        setItems(previous.items)
        selectedIndex = Math.min(previous.selectedIndex, Math.max(0, items.length - 1))
        rotationIndex = items.length > 6 ? selectedIndex : 0
        childLayerHidden = false
        pendingBack = null
        parentReturnHandoffTimer.restart()
    }

    function beginProvider(item) {
        enterMenu(item.label, [{
            id: "provider-loading", type: "status", label: "Loading…",
            description: item.description || "", icon: "", image: "", isImage: false,
            key: "", disabled: true, searchText: "loading"
        }])
        providerAwaiting = true
        providerRequested(item)
    }

    function completeProvider(providerItems, error) {
        if (!providerAwaiting || !active) return
        providerAwaiting = false
        if (error) {
            setItems([{ id: "provider-error", type: "error", label: "Provider failed",
                description: error, icon: "", image: "", isImage: false,
                key: "", disabled: true, searchText: error.toLowerCase() }])
        } else if (!providerItems.length) {
            setItems([{ id: "provider-empty", type: "status", label: "No results",
                description: "", icon: "", image: "", isImage: false,
                key: "", disabled: true, searchText: "empty" }])
        } else {
            setItems(providerItems)
        }
    }

    function goBack() {
        if (parentTransferActive || menuEntryPending || childRevealActive || childDismissActive || bandCollapseActive || parentReturnActive) return true
        if (searchMode) { endSearch(); return true }
        if (!navigationStack.length) return false
        pendingBack = navigationStack[navigationStack.length - 1]
        parentReturnStarting(pendingBack.geometry || ({}))
        childDismissProgress = 1
        bandCollapseProgress = 1
        parentReturnProgress = 0
        if (navigationStack.length > 1) {
            ancestorEnterProgress = 0
            ancestorEnterActive = true
        }
        // Only the final child -> root return changes the fan geometry.
        // Between nested levels the launcher keeps the hierarchy-sized fan;
        // otherwise it visibly shrinks to root and immediately grows again.
        childDismissActive = true
        bandCollapseActive = navigationStack.length === 1
        parentReturnActive = true
        return true
    }

    function move(delta) {
        if (parentTransferActive || menuEntryPending || childRevealActive || childDismissActive || bandCollapseActive || parentReturnActive) return
        if (!items.length) return
        const nextIndex = (selectedIndex + delta + items.length) % items.length
        selectedIndex = nextIndex
        // Small result sets fit in the fan at once. Keep their slots fixed
        // and move only the visual focus between them.
        if (items.length > 6) {
            // Keep an unbounded scroll position. Replacing this with the
            // wrapped selected index makes 10 -> 1 reset 9 -> 0 and forces
            // edge delegates to animate straight through the fan.
            rotationIndex += delta
            scrollIndex = selectedIndex
        }
    }

    function setSearch(text) {
        query = text
        const needle = text.toLowerCase()
        items = needle.length ? allItems.filter(item => item.searchText.indexOf(needle) !== -1) : allItems
        selectedIndex = Math.min(selectedIndex, Math.max(0, items.length - 1))
        rotationIndex = items.length > 6 ? selectedIndex : 0
        scrollIndex = items.length > visibleItems ? selectedIndex : Math.floor(items.length / 2)
    }

    function beginSearch() {
        if (!searchMode) savedIndex = selectedIndex
        searchMode = true
    }

    function endSearch() {
        searchMode = false
        query = ""
        items = allItems
        selectedIndex = Math.min(savedIndex, Math.max(0, items.length - 1))
        rotationIndex = items.length > 6 ? selectedIndex : 0
        scrollIndex = items.length > visibleItems ? selectedIndex : Math.floor(items.length / 2)
    }

    function respond(status, value) {
        if (!active) return
        resultFile.path = resultPath
        resultFile.setText(status + "\n" + (value || ""))
        requestId = ""
        beginClose()
    }

    function accept() {
        if (menuEntryPending || parentTransferActive || childRevealActive || childDismissActive || bandCollapseActive || parentReturnActive) return
        if (!items.length) return
        const item = items[selectedIndex]
        if (item.disabled) return
        if (mode === "dmenu" || mode === "wallpaper") {
            if (item.type === "submenu") { enterMenu(item.label, item.children); return }
            let output = item.raw !== undefined ? item.raw : item.value
            if (outputMode === "value") output = item.value
            else if (outputMode === "id") output = item.id
            else if (outputMode === "json") output = JSON.stringify(item.json || item)
            respond("selected", output + "\n")
            return
        }
        if (item.type === "submenu") { enterMenu(item.label, item.children); return }
        if (item.type === "applications") { applicationsRequested(); return }
        if (item.type === "provider") { beginProvider(item); return }
        if (item.type === "desktop" && item.desktopEntry) {
            item.desktopEntry.execute()
            beginClose()
            return
        }
        if (item.type === "command" && item.command && item.command.length) {
            commandRequested(item.command, item.workingDirectory || "")
            beginClose()
        }
    }

    function triggerKey(text) {
        if (!text || searchMode) return false
        const needle = text.toLowerCase()
        for (let i = 0; i < items.length; ++i) {
            if (items[i].key && items[i].key.toLowerCase() === needle && !items[i].disabled) {
                selectedIndex = i
                if (items.length > 6) {
                    rotationIndex = selectedIndex
                    scrollIndex = i
                }
                accept()
                return true
            }
        }
        return false
    }

    function focusFromPointer(index) {
        if (parentTransferActive || menuEntryPending || childRevealActive || childDismissActive || bandCollapseActive || parentReturnActive) return
        if (index < 0 || index >= items.length) return
        selectedIndex = index
    }

    function cancel() {
        if (goBack()) return
        if (mode === "dmenu" || mode === "wallpaper") respond("cancelled", "")
        else beginClose()
    }

    property Timer revealTimer: Timer {
        interval: 16
        onTriggered: root.presenting = true
    }

    property Timer menuEntryTimer: Timer {
        interval: root.selectionSettleMs
        onTriggered: root.startParentTransfer()
    }

    property Timer closeTimer: Timer {
        interval: root.closeAnimationMs
        onTriggered: {
            root.presenting = false
            root.closing = false
            root.active = false
        }
    }

    property Timer parentReturnHandoffTimer: Timer {
        // Keep normal-item Behaviors suppressed until the replacement
        // delegates have completed their first scene-graph frame. The incoming
        // ancestor layer must be released in this same callback: separate
        // timers create a frame with either two translucent copies or none.
        interval: 80
        onTriggered: {
            root.parentReturnHandoffActive = false
            root.ancestorEnterHandoffActive = false
            root.parentReturnSettleTimer.restart()
        }
    }

    property Timer parentReturnSettleTimer: Timer {
        interval: 32
        onTriggered: root.parentReturnSettleActive = false
    }
}
