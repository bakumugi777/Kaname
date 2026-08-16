import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root

    readonly property string stateBase: Quickshell.env("XDG_STATE_HOME")
        || (Quickshell.env("HOME") + "/.local/state")
    property string statePath: Quickshell.env("KANAME_APPLICATION_HISTORY_FILE")
        || (stateBase + "/kaname/application-usage.json")
    readonly property string stateDirectory: {
        const slash = statePath.lastIndexOf("/")
        return slash > 0 ? statePath.substring(0, slash) : stateBase + "/kaname"
    }
    property var recentIds: []
    property bool dirty: false
    property bool directoryReady: false
    property string pendingText: ""
    signal changed()

    function configuredLimit() {
        const recent = Config.applicationMenu && Config.applicationMenu.recent
            ? Config.applicationMenu.recent : ({})
        const value = Number(recent.limit)
        return isFinite(value) ? Math.max(1, Math.min(100, Math.round(value))) : 10
    }

    function normalizedIds(values) {
        const result = []
        const seen = ({})
        if (!Array.isArray(values)) return result
        const limit = configuredLimit()
        for (let i = 0; i < values.length && result.length < limit; ++i) {
            const id = typeof values[i] === "string" ? values[i] : ""
            if (!id.length || seen[id]) continue
            seen[id] = true
            result.push(id)
        }
        return result
    }

    function load() {
        if (dirty) return
        try {
            const value = JSON.parse(historyFile.text())
            if (value.schemaVersion !== 1 || !Array.isArray(value.recent))
                throw new Error("schemaVersion 1 and recent array are required")
            recentIds = normalizedIds(value.recent)
            directoryReady = true
            changed()
        } catch (failure) {
            console.warn("kaname: ignoring invalid application history:", failure)
        }
    }

    function record(desktopId) {
        const id = String(desktopId || "")
        if (!id.length) return
        dirty = true
        recentIds = normalizedIds([id].concat(recentIds))
        pendingText = JSON.stringify({ schemaVersion: 1, recent: recentIds }, null, 2) + "\n"
        changed()
        persist()
    }

    function persist() {
        if (!pendingText.length) return
        if (directoryReady) {
            historyFile.setText(pendingText)
            pendingText = ""
            return
        }
        if (!mkdirProcess.running) {
            mkdirProcess.command = ["mkdir", "-p", stateDirectory]
            mkdirProcess.running = true
        }
    }

    property FileView historyFile: FileView {
        path: root.statePath
        preload: true
        atomicWrites: true
        onLoaded: root.load()
        onFileChanged: {
            if (!root.dirty) reload()
        }
    }

    property Process mkdirProcess: Process {
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                console.warn("kaname: could not create application history directory")
                return
            }
            root.directoryReady = true
            root.persist()
        }
    }
}
