import QtQuick
import Quickshell

QtObject {
    function items() {
        const result = []
        const entries = DesktopEntries.applications.values
        for (let i = 0; i < entries.length; ++i) {
            const entry = entries[i]
            if (!entry || entry.noDisplay) continue
            result.push({
                id: "desktop:" + entry.id,
                type: "desktop",
                label: entry.name,
                description: entry.comment || entry.genericName || "",
                icon: entry.icon || "application-x-executable",
                image: "",
                isImage: false,
                value: entry.id,
                key: "",
                disabled: false,
                desktopEntry: entry,
                searchText: (entry.name + " " + entry.genericName + " " + entry.comment + " " + entry.id + " " + entry.keywords.join(" ")).toLowerCase()
            })
        }
        result.sort((a, b) => a.label.localeCompare(b.label))
        return result
    }

    function hasCategory(item, categories) {
        const entryCategories = item.desktopEntry && item.desktopEntry.categories
            ? item.desktopEntry.categories : []
        for (let i = 0; i < categories.length; ++i)
            if (entryCategories.indexOf(categories[i]) !== -1) return true
        return false
    }

    function categoryFor(item) {
        // Categories are deliberately ordered: a browser often also declares
        // Network, and an image editor may also declare Utility. Give each
        // entry one primary home while keeping it available in 全表示.
        if (hasCategory(item, ["WebBrowser", "Network"])) return "browser"
        if (hasCategory(item, ["Settings", "System", "HardwareSettings"])) return "settings"
        if (hasCategory(item, ["Audio", "Music"])) return "music"
        if (hasCategory(item, ["Graphics", "Photography", "Viewer", "Video"])) return "media"
        return "other"
    }

    function categorizedItems() {
        const all = items()
        const groups = {
            browser: [], settings: [], music: [], media: [], other: []
        }
        for (let i = 0; i < all.length; ++i)
            groups[categoryFor(all[i])].push(all[i])

        const definitions = [
            { id: "browser", label: "ブラウザ", icon: "web-browser", key: "b" },
            { id: "settings", label: "設定", icon: "preferences-system", key: "s" },
            { id: "music", label: "音楽", icon: "multimedia-player", key: "m" },
            { id: "media", label: "画像・動画", icon: "image-x-generic", key: "i" },
            { id: "other", label: "その他", icon: "applications-other", key: "o" }
        ]
        const result = []
        for (let i = 0; i < definitions.length; ++i) {
            const definition = definitions[i]
            const children = groups[definition.id]
            if (!children.length) continue
            result.push({
                id: "applications-" + definition.id,
                type: "submenu",
                label: definition.label,
                description: children.length + " 件のアプリケーション",
                icon: definition.icon,
                image: "",
                isImage: false,
                key: definition.key,
                children: children,
                searchText: definition.label.toLowerCase()
            })
        }
        result.push({
            id: "applications-all",
            type: "submenu",
            label: "全表示",
            description: all.length + " 件のアプリケーション",
            icon: "view-app-grid-symbolic",
            image: "",
            isImage: false,
            key: "a",
            children: all,
            searchText: "all applications"
        })
        return result
    }
}
