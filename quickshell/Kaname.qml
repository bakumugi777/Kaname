import QtQuick
import Quickshell
import Quickshell.Io

Scope {
    id: root
    // A dmenu caller may open another picker immediately after receiving the
    // previous result. Keep that transition out of the busy path while the
    // close animation ends.
    property var pendingRequest: null
    property string pendingApplicationsScreen: ""
    property int applicationsLoadAttempts: 0
    property int applicationsWarmupAttempts: 0
    property bool applicationsCacheReady: false
    property var applicationsCache: []
    property LauncherState launcherState: LauncherState {
        onCommandRequested: (command, workingDirectory) => {
            commandRunner.command = command
            commandRunner.workingDirectory = workingDirectory
            commandRunner.startDetached()
        }
        onApplicationsRequested: root.launcherState.enterMenu(root.applicationsTitle(),
                                                               root.cachedApplications())
        onProviderRequested: item => providerRunner.run(item)
    }
    property DmenuSource source: DmenuSource {}
    property DesktopEntrySource desktopSource: DesktopEntrySource {}
    property MenuSource menuSource: MenuSource {}

    function applicationsTitle() {
        return Config.applicationMenu && typeof Config.applicationMenu.title === "string"
            ? Config.applicationMenu.title : "Applications"
    }

    Timer {
        id: applicationsLoadTimer
        interval: 50
        repeat: false
        onTriggered: root.tryShowApplications()
    }

    Timer {
        id: applicationsWarmupTimer
        interval: 50
        repeat: false
        onTriggered: root.warmApplicationsCache()
    }

    Component.onCompleted: applicationsWarmupTimer.start()

    Connections {
        target: Config
        function onApplicationMenuChanged() {
            root.invalidateApplicationsCache()
        }
    }

    Connections {
        target: DesktopEntries
        function onApplicationsChanged() {
            // Quickshell emits this when desktop files are added, removed, or
            // refreshed. Rebuild after a short debounce because package
            // installation can update several entries in one burst.
            root.invalidateApplicationsCache()
        }
    }

    LauncherWindow { launcherState: root.launcherState }

    function activateRequest(request) {
        source.load(request.candidatesPath, request.promptPath)
        launcherState.open(request.requestId, source.candidateText, source.promptText,
                           request.resultPath, request.profile, request.inputFormat,
                           request.outputMode, request.screen)
    }

    function cacheApplications(entries) {
        applicationsCache = desktopSource.categorizedItems(entries)
        applicationsCacheReady = true
    }

    function invalidateApplicationsCache() {
        applicationsCacheReady = false
        applicationsCache = []
        applicationsWarmupAttempts = 0
        applicationsWarmupTimer.restart()
    }

    function warmApplicationsCache() {
        if (applicationsCacheReady) return
        const entries = desktopSource.items()
        if (entries.length) {
            cacheApplications(entries)
            applicationsWarmupAttempts = 0
            return
        }
        if (applicationsWarmupAttempts++ < 40) applicationsWarmupTimer.restart()
    }

    function cachedApplications() {
        if (applicationsCacheReady) return applicationsCache
        const entries = desktopSource.items()
        if (entries.length) {
            cacheApplications(entries)
            return applicationsCache
        }
        return []
    }

    function tryShowApplications() {
        if (launcherState.active) {
            pendingApplicationsScreen = ""
            applicationsLoadAttempts = 0
            return
        }
        if (applicationsCacheReady) {
            const screen = pendingApplicationsScreen
            pendingApplicationsScreen = ""
            applicationsLoadAttempts = 0
            launcherState.openItems("applications", applicationsTitle(), applicationsCache, screen)
            return
        }
        // Enumerate once per readiness attempt. Previously categorizedItems()
        // and items() each traversed and sorted the complete desktop database.
        const entries = desktopSource.items()
        if (entries.length) {
            cacheApplications(entries)
            tryShowApplications()
            return
        }
        if (applicationsLoadAttempts >= 40) {
            const screen = pendingApplicationsScreen
            pendingApplicationsScreen = ""
            applicationsLoadAttempts = 0
            launcherState.openItems("applications", applicationsTitle(), [], screen)
            return
        }
        applicationsLoadAttempts += 1
        applicationsLoadTimer.restart()
    }

    Connections {
        target: root.launcherState
        function onActiveChanged() {
            if (!root.launcherState.active && root.pendingRequest) {
                const request = root.pendingRequest
                root.pendingRequest = null
                root.activateRequest(request)
            }
        }
    }

    IpcHandler {
        target: "kaname"

        function openRequest(requestId: string, candidatesPath: string, promptPath: string, resultPath: string, profile: string, inputFormat: string, outputMode: string, screen: string): void {
            if (root.launcherState.active) {
                // A completed dmenu request clears requestId before its close
                // animation finishes. Queue the next sequential request then.
                if (root.launcherState.mode === "dmenu" && !root.launcherState.requestId && !root.pendingRequest) {
                    root.pendingRequest = {
                        requestId: requestId, candidatesPath: candidatesPath, promptPath: promptPath,
                        resultPath: resultPath, profile: profile, inputFormat: inputFormat || "lines",
                        outputMode: outputMode || "raw", screen: screen
                    }
                    return
                }
                busyFile.path = resultPath
                busyFile.setText("busy\n")
                return
            }
            root.activateRequest({
                requestId: requestId, candidatesPath: candidatesPath, promptPath: promptPath,
                resultPath: resultPath, profile: profile, inputFormat: inputFormat || "lines",
                outputMode: outputMode || "raw", screen: screen
            })
        }

        function close(): void { root.launcherState.cancel() }
        function closeRequest(requestId: string): void {
            if (root.launcherState.mode === "dmenu"
                    && root.launcherState.requestId === requestId)
                root.launcherState.cancel()
            if (root.pendingRequest && root.pendingRequest.requestId === requestId)
                root.pendingRequest = null
            root.launcherState.releaseCompletedRequest(requestId)
        }

        // Used by the blocking CLI as a liveness check. This is deliberately
        // independent of elapsed time: an interactive request may remain open
        // indefinitely, but a request no longer owned by this instance must
        // not leave its terminal waiting forever.
        function requestStatus(requestId: string): string {
            if (root.launcherState.requestId === requestId && root.launcherState.active)
                return "active"
            if (root.pendingRequest && root.pendingRequest.requestId === requestId)
                return "pending"
            if (root.launcherState.completingRequestId === requestId)
                return "completing"
            return "missing"
        }

        function showApplications(screen: string): void {
            if (root.launcherState.active) return
            root.pendingApplicationsScreen = screen
            root.applicationsLoadAttempts = 0
            root.tryShowApplications()
        }

        function showMenu(name: string, screen: string): void {
            if (root.launcherState.active) return
            const menu = root.menuSource.menu(name)
            if (menu) {
                root.launcherState.openItems("menu", menu.label, menu.items, screen)
            } else {
                root.launcherState.openItems("menu", "Menu error", [{
                    id: "menu-error", type: "error", label: "Menu not found: " + name,
                    description: root.menuSource.error, icon: "dialog-error", image: "",
                    isImage: false, disabled: true, key: "", searchText: name.toLowerCase()
                }], screen)
            }
        }

        // Built-in manual fixture for validating arbitrary-depth navigation.
        // It intentionally does not depend on the user's menus.json.
        function showHierarchyDemo(screen: string): void {
            if (root.launcherState.active) return
            root.launcherState.openItems("menu", "Hierarchy demo", [{
                id: "demo-root-a", type: "submenu", label: "Level 1 · A",
                description: "Enter to open level 2", icon: "folder", key: "a",
                children: [{
                    id: "demo-a-1", type: "submenu", label: "Level 2 · A-1",
                    description: "Enter to open level 3", icon: "folder", key: "1",
                    children: [{
                        id: "demo-a-1-i", type: "submenu", label: "Level 3 · A-1-i",
                        description: "Enter to open a leaf level", icon: "folder", key: "i",
                        children: [{ id: "demo-a-leaf", type: "status", label: "Level 4 leaf",
                            description: "Backspace returns; Escape closes", icon: "emblem-ok",
                            disabled: true, key: "", searchText: "demo leaf" }]
                    }]
                }]
            }, {
                id: "demo-root-b", type: "submenu", label: "Level 1 · B",
                description: "A second branch for position checks", icon: "folder", key: "b",
                children: [{
                    id: "demo-b-1", type: "submenu", label: "Level 2 · B-1",
                    description: "Enter to open level 3", icon: "folder", key: "1",
                    children: [{ id: "demo-b-leaf", type: "status", label: "Level 3 leaf",
                        description: "Backspace returns; Escape closes", icon: "emblem-ok",
                        disabled: true, key: "", searchText: "demo leaf" }]
                }]
            }], screen)
        }
    }

    FileView { id: busyFile; atomicWrites: true }
    Process { id: commandRunner }
    ProviderRunner {
        id: providerRunner
        onCompleted: (items, error) => root.launcherState.completeProvider(items, error)
    }
}

