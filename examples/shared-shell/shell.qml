import Quickshell
// Place or symlink Kaname's quickshell directory here as ./Kaname first.
import "Kaname" as KanameModule

ShellRoot {
    // Other shared-shell components can live beside Kaname.
    KanameModule.Kaname {}
}
