import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property string path: Quickshell.env("KANAME_MENUS_FILE") || (Quickshell.env("HOME") + "/.config/kaname/menus.json")
    property string defaultPath: Quickshell.env("KANAME_DEFAULT_MENUS_FILE") || Quickshell.shellPath("../config/menus.json")
    property var menus: ({})
    property string error: ""
    signal changed()

    function normalize(item, prefix, index) {
        if (!item || typeof item !== "object") throw new Error(prefix + ": item " + index + " is not an object")
        const type = item.type || (item.children ? "submenu" : "command")
        const id = item.id || (prefix + ":" + index)
        const label = item.label || id
        if (type === "command" && (!Array.isArray(item.command) || item.command.length === 0))
            throw new Error(id + ": command must be a non-empty array")
        if (type === "provider" && (!Array.isArray(item.command) || item.command.length === 0))
            throw new Error(id + ": provider command must be a non-empty array")
        if (type === "submenu" && !Array.isArray(item.children))
            throw new Error(id + ": children must be an array")
        const children = []
        if (Array.isArray(item.children))
            for (let i = 0; i < item.children.length; ++i) children.push(normalize(item.children[i], id, i))
        return {
            id: id,
            type: type,
            label: label,
            description: item.description || "",
            icon: item.icon || (type === "submenu" ? "folder" : "application-x-executable"),
            image: item.image || "",
            isImage: !!item.image,
            value: item.value || id,
            keywords: Array.isArray(item.keywords) ? item.keywords : [],
            key: item.key || "",
            disabled: item.disabled === true,
            command: Array.isArray(item.command) ? item.command : [],
            workingDirectory: item.workingDirectory || "",
            inputFormat: item.inputFormat === "jsonl" ? "jsonl" : "lines",
            children: children,
            searchText: (label + " " + (item.description || "") + " " + (item.keywords || []).join(" ")).toLowerCase()
        }
    }

    function loadText(text) {
        try {
            const value = JSON.parse(text)
            if (value.schemaVersion !== 1 || !value.menus || typeof value.menus !== "object")
                throw new Error("schemaVersion 1 and menus object are required")
            const next = {}
            for (const name of Object.keys(value.menus)) {
                const menu = value.menus[name]
                if (!menu || !Array.isArray(menu.items)) throw new Error(name + ": items must be an array")
                const items = []
                for (let i = 0; i < menu.items.length; ++i) items.push(normalize(menu.items[i], name, i))
                next[name] = { label: menu.label || name, items: items }
            }
            menus = next
            error = ""
            changed()
        } catch (failure) {
            error = String(failure)
            console.warn("kaname: keeping last valid menus:", failure)
        }
    }

    function menu(name) { return menus[name] }

    property FileView file: FileView {
        path: root.path
        watchChanges: true
        preload: true
        onLoaded: root.loadText(text())
        onFileChanged: reload()
    }

    property FileView defaultFile: FileView {
        path: root.defaultPath
        preload: true
        onLoaded: {
            if (Object.keys(root.menus).length === 0) root.loadText(text())
        }
    }
}
