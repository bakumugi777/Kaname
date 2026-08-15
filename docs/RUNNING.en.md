# Running Kaname

This guide explains the relationship between the `kaname` CLI,
`kaname-shell`, and Quickshell, including standalone and embedded Niri setups.

## Process model

`kaname` is a short-lived CLI which sends a display request to Quickshell.
The resident process is normally `quickshell`, not `kaname`.

```text
kaname --applications
        │ IPC
        ▼
Quickshell process
└── Kaname.qml
    └── LauncherWindow, visible only while in use
```

If no matching Quickshell instance exists, the CLI starts one as a daemon.
Closing the launcher hides its window but leaves Quickshell waiting for the
next IPC request.

## Standalone mode

`kaname-shell` starts the dedicated Kaname configuration in the foreground.

```bash
kaname-shell
kaname --applications
```

Explicit autostart is optional because the CLI can start it on first use.
Autostart avoids the additional delay on the first invocation.

Niri example:

```kdl
spawn-at-startup "kaname-shell"

binds {
    Mod+Space { spawn "kaname" "--applications"; }
}
```

If a `binds` block already exists, add the binding to it instead of creating a
second block. Validate the configuration with `niri validate`.

The Home Manager systemd service shown in the main README is an alternative to
`spawn-at-startup`. Do not enable both. Service logs are available with:

```bash
systemctl --user status kaname.service
journalctl --user -u kaname.service -b
```

## Embedded shared-shell mode

Place the Kaname QML directory inside the shared configuration and instantiate
the component from its `ShellRoot`:

```qml
import Quickshell
import "Kaname" as KanameModule

ShellRoot {
    KanameModule.Kaname {}
    // MyPanel {}
    // MyNotificationCenter {}
}
```

Start the shared configuration instead of `kaname-shell`:

```bash
quickshell -p "$HOME/.config/quickshell/shared" --daemonize
KANAME_QML_DIR="$HOME/.config/quickshell/shared" kaname --applications
```

`KANAME_QML_DIR` must point the CLI at the shared configuration. If it is
omitted, the CLI may start a separate standalone Kaname instance.

Niri does not run the `spawn` action through a shell. Replace `/home/USER` with
the actual absolute path rather than relying on `$HOME` or `~` expansion.

```kdl
spawn-at-startup "quickshell" "-p" "/home/USER/.config/quickshell/shared"

binds {
    Mod+Space {
        spawn "env" "KANAME_QML_DIR=/home/USER/.config/quickshell/shared" "kaname" "--applications";
    }
}
```

Home Manager can install the module and export the CLI target:

```nix
xdg.configFile."quickshell/shared/Kaname".source =
  "${kanamePackage}/share/kaname/quickshell";

home.sessionVariables.KANAME_QML_DIR =
  "${config.xdg.configHome}/quickshell/shared";
```

Choose either Niri autostart or a systemd user service for the shared shell,
not both.

## Inspecting and stopping instances

```bash
quickshell list
pgrep -af quickshell
quickshell kill -p "$HOME/.config/quickshell/shared"
systemctl --user stop kaname.service
```

Pressing Escape closes the launcher window, not the resident Quickshell
process.

Standalone mode is simpler and isolates failures. Shared mode is preferable
when several QML tools should share one Qt/Quickshell runtime and its resident
memory. Running standalone and embedded Kaname instances at the same time is
not recommended because both expose the `kaname` IPC target.

Kaname is developed and tested on NixOS/Niri. Other layer-shell Wayland
compositors may work, but placement and focus behavior are unsupported. X11 is
outside the supported scope.
