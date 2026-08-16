pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property string configPath: Quickshell.env("KANAME_CONFIG_FILE") || (Quickshell.env("HOME") + "/.config/kaname/config.json")
    property int windowWidth: 1100
    property int windowHeight: 900
    property real centerOffsetX: 0
    property real centerOffsetY: 0
    property real radius: 760
    property real startAngle: 180
    property real endAngle: 270
    property int visibleItems: 7
    property real itemWidth: 150
    property real itemHeight: 104
    property real masterOpacity: 1.0
    property real backgroundOpacity: 0.72
    property real overlayOpacity: 0.10
    property real itemOpacity: 0.92
    property real inactiveOpacity: 0.50
    property real guideOpacity: 0.32
    property real fanOpacity: 0.22
    property real textOpacity: 1.0
    property real imageOpacity: 1.0
    property int animationMs: 180
    property int themeAnimationMs: 350
    property bool reducedMotion: false
    property int cacheRadius: 1
    property string enterLevelKey: "Left"
    property string backLevelKey: "Right"
    property string themePreset: "matugen"
    property string defaultScreen: ""
    property var profiles: ({})
    readonly property var defaultApplicationMenu: ({
        title: "Applications",
        description: "{count} applications",
        categories: [
            { id: "browser", label: "Browsers", icon: "web-browser", key: "b",
                match: ["WebBrowser", "Network"] },
            { id: "settings", label: "Settings", icon: "preferences-system", key: "s",
                match: ["Settings", "System", "HardwareSettings"] },
            { id: "media", label: "Media", icon: "applications-multimedia", key: "m",
                children: [
                    { id: "music", label: "Music", icon: "multimedia-player", key: "m",
                        match: ["Audio", "Music"] },
                    { id: "images", label: "Images", icon: "image-x-generic", key: "i",
                        match: ["Graphics", "Photography", "2DGraphics", "RasterGraphics", "VectorGraphics"] },
                    { id: "videos", label: "Videos", icon: "video-x-generic", key: "v",
                        match: ["Video", "VideoEditing", "TV"] }
                ] },
            { id: "tools", label: "Tools", icon: "applications-utilities", key: "t",
                match: ["Utility", "Development", "FileManager", "TerminalEmulator", "TextEditor", "Archiving"] }
        ],
        recent: { id: "recent", label: "Recently Used", icon: "document-open-recent",
            key: "r", limit: 10 },
        fallback: { id: "other", label: "Other", icon: "applications-other", key: "o" },
        all: { id: "all", label: "All Applications", icon: "view-app-grid-symbolic", key: "a" }
    })
    property var applicationMenu: defaultApplicationMenu

    function number(value, fallback, minimum, maximum) {
        return typeof value === "number" && isFinite(value) ? Math.max(minimum, Math.min(maximum, value)) : fallback
    }

    function profileValue(name, group, key, fallback) {
        const profile = profiles && profiles[name] ? profiles[name] : null
        return profile && profile[group] && profile[group][key] !== undefined ? profile[group][key] : fallback
    }

    function motionDuration(value) { return reducedMotion ? 0 : value }

    function keyCode(name) {
        switch (String(name || "").toLowerCase()) {
        case "left": return Qt.Key_Left
        case "right": return Qt.Key_Right
        case "up": return Qt.Key_Up
        case "down": return Qt.Key_Down
        case "backspace": return Qt.Key_Backspace
        case "return": return Qt.Key_Return
        case "enter": return Qt.Key_Enter
        case "escape": return Qt.Key_Escape
        case "space": return Qt.Key_Space
        case "tab": return Qt.Key_Tab
        default: return 0
        }
    }

    function keyBinding(value, fallback) {
        if (typeof value !== "string") return fallback
        return value.toLowerCase() === "none" || keyCode(value) !== 0 ? value : fallback
    }

    function matchesKey(key, binding) {
        if (String(binding || "").toLowerCase() === "none") return false
        const configured = keyCode(binding)
        return configured !== 0 && key === configured
    }

    function applyConfig() {
        try {
            const value = JSON.parse(configFile.text())
            if (value.schemaVersion !== 1) throw new Error("unsupported config schema")
            const g = value.geometry || {}
            const o = value.opacity || {}
            const b = value.behavior || {}
            const keys = b.keyBindings || {}
            const t = value.theme || {}
            const d = value.display || {}
            windowWidth = number(g.width, windowWidth, 320, 4096)
            windowHeight = number(g.height, windowHeight, 240, 4096)
            centerOffsetX = number(g.centerOffsetX, centerOffsetX, -1000, 1000)
            centerOffsetY = number(g.centerOffsetY, centerOffsetY, -1000, 1000)
            radius = number(g.radius, radius, 80, 2000)
            startAngle = number(g.startAngle, startAngle, -720, 720)
            endAngle = number(g.endAngle, endAngle, -720, 720)
            visibleItems = Math.round(number(g.visibleItems, visibleItems, 1, 15))
            itemWidth = number(g.itemWidth, itemWidth, 48, 500)
            itemHeight = number(g.itemHeight, itemHeight, 48, 500)
            masterOpacity = number(o.master, masterOpacity, 0, 1)
            backgroundOpacity = number(o.background, backgroundOpacity, 0, 1)
            overlayOpacity = number(o.overlay, overlayOpacity, 0, 1)
            itemOpacity = number(o.item, itemOpacity, 0, 1)
            inactiveOpacity = number(o.inactive, inactiveOpacity, 0, 1)
            guideOpacity = number(o.guide, guideOpacity, 0, 1)
            fanOpacity = number(o.fan, fanOpacity, 0, 1)
            textOpacity = number(o.text, textOpacity, 0, 1)
            imageOpacity = number(o.image, imageOpacity, 0, 1)
            animationMs = Math.round(number(b.animationMs, animationMs, 0, 2000))
            themeAnimationMs = Math.round(number(b.themeAnimationMs, themeAnimationMs, 0, 5000))
            reducedMotion = b.reducedMotion === true
            cacheRadius = Math.round(number(b.cacheRadius, cacheRadius, 0, 5))
            enterLevelKey = keyBinding(keys.enterLevel, enterLevelKey)
            backLevelKey = keyBinding(keys.backLevel, backLevelKey)
            themePreset = typeof t.preset === "string" ? t.preset : themePreset
            defaultScreen = typeof d.screen === "string" ? d.screen : defaultScreen
            profiles = value.profiles && typeof value.profiles === "object" ? value.profiles : ({})
            applicationMenu = value.applications && typeof value.applications === "object"
                ? value.applications : defaultApplicationMenu
        } catch (error) {
            console.warn("kaname: keeping last valid config:", error)
        }
    }

    property FileView configFile: FileView {
        path: root.configPath
        watchChanges: true
        preload: true
        onLoaded: root.applyConfig()
        onFileChanged: reload()
    }
}
