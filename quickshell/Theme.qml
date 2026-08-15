pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

QtObject {
    id: root
    property string themePath: Quickshell.env("KANAME_THEME_FILE") || (Quickshell.env("HOME") + "/.cache/matugen/kaname-colors.json")
    property color background: "#111318"
    property color surface: "#191c22"
    property color surfaceContainer: "#20242b"
    property color primary: "#afc6ff"
    property color secondary: "#c0c6dc"
    property color tertiary: "#dfc0e8"
    property color outline: "#8c9099"
    property color text: "#e2e2e9"
    property color textMuted: "#c5c6d0"
    property color error: "#ffb4ab"
    // A dark, visibly themed control surface. Keep primary out of this mix so
    // the primary-coloured selection glow retains clear colour contrast.
    readonly property color controlSurface: Qt.rgba(
        background.r * 0.58 + surface.r * 0.26 + secondary.r * 0.10 + tertiary.r * 0.06,
        background.g * 0.58 + surface.g * 0.26 + secondary.g * 0.10 + tertiary.g * 0.06,
        background.b * 0.58 + surface.b * 0.26 + secondary.b * 0.10 + tertiary.b * 0.06,
        1)
    property int transitionMs: Config.motionDuration(Config.themeAnimationMs)

    function applyPreset() {
        const presets = {
            "dark": ["#0b0d12", "#151821", "#202633", "#9fc3ff", "#bdc7dc", "#d7bde8", "#8892a4", "#edf1f8", "#b9c1ce", "#ffb4ab"],
            "neon": ["#070a12", "#101827", "#17243a", "#64d8ff", "#ff77d4", "#bda2ff", "#5686a6", "#eaf8ff", "#a9c8d8", "#ff6b86"],
            "mono": ["#0d0d0d", "#181818", "#242424", "#eeeeee", "#c8c8c8", "#a8a8a8", "#777777", "#f5f5f5", "#bdbdbd", "#ffb4ab"]
        }
        if (Config.themePreset === "matugen") return
        const value = presets[Config.themePreset] || presets.dark
        const keys = ["background", "surface", "surfaceContainer", "primary", "secondary", "tertiary", "outline", "text", "textMuted", "error"]
        for (let i = 0; i < keys.length; ++i) root[keys[i]] = value[i]
    }

    function applyTheme() {
        if (Config.themePreset !== "matugen") { applyPreset(); return }
        try {
            const value = JSON.parse(themeFile.text())
            if (value.schemaVersion !== 1 || !value.background || !value.primary || !value.text)
                throw new Error("missing required theme keys")
            for (const key of ["background", "surface", "surfaceContainer", "primary", "secondary", "tertiary", "outline", "text", "textMuted", "error"])
                if (value[key] !== undefined) root[key] = value[key]
        } catch (error) {
            console.warn("kaname: keeping last valid theme:", error)
        }
    }

    Component.onCompleted: applyPreset()
    property Connections configConnection: Connections {
        target: Config
        function onThemePresetChanged() {
            root.applyPreset()
            if (Config.themePreset === "matugen" && root.themeFile.loaded) root.applyTheme()
        }
    }

    property FileView themeFile: FileView {
        path: root.themePath
        watchChanges: true
        preload: true
        onLoaded: root.applyTheme()
        onFileChanged: reload()
    }

    Behavior on background { ColorAnimation { duration: root.transitionMs } }
    Behavior on surface { ColorAnimation { duration: root.transitionMs } }
    Behavior on surfaceContainer { ColorAnimation { duration: root.transitionMs } }
    Behavior on primary { ColorAnimation { duration: root.transitionMs } }
    Behavior on secondary { ColorAnimation { duration: root.transitionMs } }
    Behavior on tertiary { ColorAnimation { duration: root.transitionMs } }
    Behavior on outline { ColorAnimation { duration: root.transitionMs } }
    Behavior on text { ColorAnimation { duration: root.transitionMs } }
    Behavior on textMuted { ColorAnimation { duration: root.transitionMs } }
    Behavior on error { ColorAnimation { duration: root.transitionMs } }
}
