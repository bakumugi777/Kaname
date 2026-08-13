import QtQuick
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    // A dmenu caller commonly opens its next picker immediately after receiving
    // the previous result (for example Image/Video -> thumbnail picker). Keep
    // that one transition out of the "busy" path while the close animation ends.
    property var pendingRequest: null
    property LauncherState launcherState: LauncherState {
        onCommandRequested: (command, workingDirectory) => {
            commandRunner.command = command
            commandRunner.workingDirectory = workingDirectory
            commandRunner.startDetached()
        }
        onApplicationsRequested: root.launcherState.enterMenu("アプリケーション", root.desktopSource.categorizedItems())
        onProviderRequested: item => providerRunner.run(item)
    }
    property DmenuSource source: DmenuSource {}
    property DmenuSource imageSource: DmenuSource {}
    property DmenuSource videoSource: DmenuSource {}
    property DesktopEntrySource desktopSource: DesktopEntrySource {}
    property MenuSource menuSource: MenuSource {}

    LauncherWindow { launcherState: root.launcherState }

    function activateRequest(request) {
        source.load(request.candidatesPath, request.promptPath)
        launcherState.open(request.requestId, source.candidateText, source.promptText,
                           request.resultPath, request.profile, request.inputFormat,
                           request.outputMode, request.screen)
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

        function openWallpaperRequest(requestId: string, imagesPath: string, videosPath: string, promptPath: string, resultPath: string, profile: string, outputMode: string, screen: string): void {
            if (root.launcherState.active) {
                busyFile.path = resultPath
                busyFile.setText("busy\n")
                return
            }
            root.imageSource.load(imagesPath, promptPath)
            root.videoSource.load(videosPath, promptPath)
            root.launcherState.openWallpaper(requestId, root.imageSource.candidateText,
                                             root.videoSource.candidateText,
                                             root.imageSource.promptText, resultPath,
                                             profile, outputMode || "raw", screen)
        }

        function close(): void { root.launcherState.cancel() }
        function closeRequest(requestId: string): void {
            if ((root.launcherState.mode === "dmenu" || root.launcherState.mode === "wallpaper")
                    && root.launcherState.requestId === requestId)
                root.launcherState.cancel()
            if (root.pendingRequest && root.pendingRequest.requestId === requestId)
                root.pendingRequest = null
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
            return "missing"
        }

        function showApplications(screen: string): void {
            if (root.launcherState.active) return
            root.launcherState.openItems("applications", "アプリケーション", root.desktopSource.categorizedItems(), screen)
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
                            description: "Use Escape / Backspace to return", icon: "emblem-ok",
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
                        description: "Use Escape / Backspace to return", icon: "emblem-ok",
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
