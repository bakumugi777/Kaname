import QtQuick
import Quickshell

QtObject {
    id: root
    property var recentIds: []

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

    function normalizeDefinitions(configured) {
        const result = []
        for (let i = 0; i < configured.length; ++i) {
            const value = configured[i]
            if (!value || typeof value.id !== "string" || !value.id.length) continue
            result.push({
                id: value.id,
                label: typeof value.label === "string" ? value.label : value.id,
                icon: typeof value.icon === "string" ? value.icon : "folder",
                key: typeof value.key === "string" ? value.key : "",
                match: Array.isArray(value.match) ? value.match : [],
                children: Array.isArray(value.children)
                    ? normalizeDefinitions(value.children) : []
            })
        }
        return result
    }

    function definitions() {
        const configured = Config.applicationMenu && Array.isArray(Config.applicationMenu.categories)
            ? Config.applicationMenu.categories : []
        return normalizeDefinitions(configured)
    }

    function leafDefinitions(definitions, result) {
        const leaves = result || []
        for (let i = 0; i < definitions.length; ++i) {
            if (definitions[i].children.length)
                leafDefinitions(definitions[i].children, leaves)
            else
                leaves.push(definitions[i])
        }
        return leaves
    }

    function categoryFor(item, categories, fallbackId) {
        // First match wins, so config order also defines precedence for desktop
        // entries which advertise several freedesktop categories.
        for (let i = 0; i < categories.length; ++i)
            if (hasCategory(item, categories[i].match)) return categories[i].id
        return fallbackId
    }

    function categoryDescription(count) {
        const format = Config.applicationMenu
            && typeof Config.applicationMenu.description === "string"
            ? Config.applicationMenu.description : "{count} applications"
        return format.replace("{count}", String(count))
    }

    function definitionCount(definition, groups) {
        if (!definition.children.length)
            return groups[definition.id] ? groups[definition.id].length : 0
        let count = 0
        for (let i = 0; i < definition.children.length; ++i)
            count += definitionCount(definition.children[i], groups)
        return count
    }

    function categoryItem(definition, groups) {
        const count = definitionCount(definition, groups)
        if (!count) return null
        const children = []
        if (definition.children.length) {
            for (let i = 0; i < definition.children.length; ++i) {
                const child = categoryItem(definition.children[i], groups)
                if (child) children.push(child)
            }
        } else {
            const applications = groups[definition.id] || []
            for (let i = 0; i < applications.length; ++i) children.push(applications[i])
        }
        return {
            id: "applications-" + definition.id,
            type: "submenu",
            label: definition.label,
            description: categoryDescription(count),
            icon: definition.icon,
            image: "",
            isImage: false,
            key: definition.key,
            children: children,
            searchText: definition.label.toLowerCase()
        }
    }

    function categorizedItems(sourceItems) {
        // Callers which already probed DesktopEntries can pass that snapshot so
        // startup readiness checks do not enumerate and sort every entry twice.
        const all = sourceItems || items()
        const categories = definitions()
        const leaves = leafDefinitions(categories)
        const fallbackConfig = Config.applicationMenu && Config.applicationMenu.fallback
            ? Config.applicationMenu.fallback : ({})
        const fallbackEnabled = fallbackConfig.enabled !== false
        const fallbackId = typeof fallbackConfig.id === "string" && fallbackConfig.id.length
            ? fallbackConfig.id : "other"
        const groups = ({})
        for (let i = 0; i < leaves.length; ++i) groups[leaves[i].id] = []
        if (fallbackEnabled) groups[fallbackId] = []
        for (let i = 0; i < all.length; ++i)
        {
            const groupId = categoryFor(all[i], leaves, fallbackEnabled ? fallbackId : "")
            if (groupId && groups[groupId]) groups[groupId].push(all[i])
        }

        const result = []
        // All Applications is the primary entry point. Keeping it at index 0
        // also makes LauncherState's normal initial selection focus it without
        // a mode-specific selection override.
        const allConfig = Config.applicationMenu && Config.applicationMenu.all
            ? Config.applicationMenu.all : ({})
        if (allConfig.enabled !== false) {
            const allId = typeof allConfig.id === "string" && allConfig.id.length ? allConfig.id : "all"
            const allLabel = typeof allConfig.label === "string" ? allConfig.label : "All Applications"
            result.push({
                id: "applications-" + allId, type: "submenu", label: allLabel,
                description: categoryDescription(all.length),
                icon: typeof allConfig.icon === "string" ? allConfig.icon : "view-app-grid-symbolic",
                image: "", isImage: false,
                key: typeof allConfig.key === "string" ? allConfig.key : "",
                children: all, searchText: "all applications " + allLabel.toLowerCase()
            })
        }

        const recentConfig = Config.applicationMenu && Config.applicationMenu.recent
            ? Config.applicationMenu.recent : ({})
        if (recentConfig.enabled !== false) {
            const byId = ({})
            for (let i = 0; i < all.length; ++i) byId[all[i].value] = all[i]
            const recentApplications = []
            const limitValue = Number(recentConfig.limit)
            const recentLimit = isFinite(limitValue)
                ? Math.max(1, Math.min(100, Math.round(limitValue))) : 10
            for (let i = 0; i < root.recentIds.length && recentApplications.length < recentLimit; ++i) {
                const application = byId[root.recentIds[i]]
                if (application) recentApplications.push(application)
            }
            const recentId = typeof recentConfig.id === "string" && recentConfig.id.length
                ? recentConfig.id : "recent"
            const recentLabel = typeof recentConfig.label === "string"
                ? recentConfig.label : "Recently Used"
            const recentChildren = recentApplications.length ? recentApplications : [{
                id: "applications-recent-empty", type: "status", label: "No recent applications",
                description: "Applications launched from Kaname appear here",
                icon: "document-open-recent", image: "", isImage: false,
                value: "", key: "", disabled: true, searchText: "no recent applications"
            }]
            result.push({
                id: "applications-" + recentId, type: "submenu", label: recentLabel,
                description: categoryDescription(recentApplications.length),
                icon: typeof recentConfig.icon === "string"
                    ? recentConfig.icon : "document-open-recent",
                image: "", isImage: false,
                key: typeof recentConfig.key === "string" ? recentConfig.key : "",
                children: recentChildren,
                searchText: "recent applications " + recentLabel.toLowerCase()
            })
        }
        for (let i = 0; i < categories.length; ++i) {
            const item = categoryItem(categories[i], groups)
            if (item) result.push(item)
        }
        if (fallbackEnabled && groups[fallbackId].length) {
            const label = typeof fallbackConfig.label === "string" ? fallbackConfig.label : fallbackId
            result.push({
                id: "applications-" + fallbackId, type: "submenu", label: label,
                description: categoryDescription(groups[fallbackId].length),
                icon: typeof fallbackConfig.icon === "string" ? fallbackConfig.icon : "applications-other",
                image: "", isImage: false,
                key: typeof fallbackConfig.key === "string" ? fallbackConfig.key : "",
                children: groups[fallbackId], searchText: label.toLowerCase()
            })
        }
        return result
    }
}
