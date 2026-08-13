import QtQuick
import Quickshell.Io

QtObject {
    id: root
    property var pendingItem: null
    signal completed(var items, string error)

    function run(item) {
        if (process.running) {
            completed([], "provider is already running")
            return
        }
        pendingItem = item
        process.command = item.command
        process.workingDirectory = item.workingDirectory || ""
        process.running = true
    }

    function parseOutput(text, format) {
        const result = []
        const lines = text.split("\n")
        for (let i = 0; i < lines.length; ++i) {
            if (!lines[i].length) continue
            if (format === "jsonl") {
                let value
                try { value = JSON.parse(lines[i]) }
                catch (failure) { throw new Error("line " + (i + 1) + ": " + failure) }
                const label = value.label || value.value || value.id
                if (!label) throw new Error("line " + (i + 1) + ": label, value, or id is required")
                if (value.type === "command" && (!Array.isArray(value.command) || !value.command.length))
                    throw new Error("line " + (i + 1) + ": command must be an array")
                result.push({
                    id: value.id || "provider:" + i,
                    type: value.type || "value",
                    label: String(label),
                    description: value.description || "",
                    icon: value.icon || "",
                    image: value.image || "",
                    isImage: !!value.image,
                    value: value.value !== undefined ? String(value.value) : lines[i],
                    raw: lines[i],
                    keywords: Array.isArray(value.keywords) ? value.keywords : [],
                    key: value.key || "",
                    disabled: value.disabled === true || (!value.command && value.type !== "submenu"),
                    command: Array.isArray(value.command) ? value.command : [],
                    workingDirectory: value.workingDirectory || "",
                    children: Array.isArray(value.children) ? value.children : [],
                    searchText: (label + " " + (value.description || "") + " " + (value.keywords || []).join(" ") + " " + (value.value || "")).toLowerCase()
                })
            } else {
                result.push({
                    id: "provider:" + i, type: "value", label: lines[i], description: "",
                    icon: "", image: "", isImage: false, value: lines[i], raw: lines[i],
                    key: "", disabled: true, searchText: lines[i].toLowerCase()
                })
            }
        }
        return result
    }

    property Process process: Process {
        stdout: StdioCollector { id: stdoutCollector; waitForEnd: true }
        stderr: StdioCollector { id: stderrCollector; waitForEnd: true }
        onExited: (exitCode, exitStatus) => {
            if (exitCode !== 0) {
                root.completed([], stderrCollector.text.trim() || ("provider exited with code " + exitCode))
            } else {
                try {
                    root.completed(root.parseOutput(stdoutCollector.text, root.pendingItem.inputFormat || "lines"), "")
                } catch (failure) {
                    root.completed([], String(failure))
                }
            }
            root.pendingItem = null
        }
    }
}
