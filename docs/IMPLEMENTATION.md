# Kaname implementation notes

## Fixed runtime

The prototype targets **Quickshell 0.3.0**, as observed on the target NixOS
machine. `flake.lock` pins the nixpkgs revision supplying it. Use `nix develop`
or `nix run .`. The development shell rejects another Quickshell version because
the pre-1.0 IPC and layer-shell APIs can change.

## Window and IPC

`LauncherWindow.qml` is a transparent `PanelWindow`, anchored right and bottom,
with no exclusive zone. It requests the overlay layer and exclusive keyboard
focus while visible. Its finite surface avoids covering the whole output;
transparent areas inside that surface cancel on click.

`kaname` creates a mode-0700 request directory under `$XDG_RUNTIME_DIR`, writes
stdin and the prompt to files, and sends only an opaque request ID and paths over
`IpcHandler`. QML atomically writes `selected`, `cancelled`, or `busy` to that
request's result file. The exact original candidate follows the status. Only the
CLI emits it to stdout. Phase 1 rejects concurrent requests rather than risking
misrouting.

## Components

- `shell.qml`: minimal standalone `ShellRoot` entry point
- `Kaname.qml`: embeddable `Scope`, composition, and IPC endpoint
- `LauncherState.qml`: request, filtering, selection, and response lifecycle
- `DmenuSource.qml`: request-owned input files
- `LauncherWindow.qml`: layer-shell window and input routing
- `FanLayout.qml` / `FanItem.qml`: polar placement and delegates
- `Theme.qml`: last-known-good semantic palette and watched JSON
- `config/default.json`: adjustable geometry, opacity, and animation trial values

`Kaname.qml` can be imported into another Quickshell configuration as a local
directory module. The standalone entry point instantiates the same component,
so embedded and standalone operation do not maintain separate implementations.
The CLI selects the owning Quickshell configuration with `KANAME_QML_DIR`; an
embedded host must point this variable at the shared shell path.

The initial UI values are seven items, radius 760, and angles 180–270 degrees.
Delegates are clamped to an eight-pixel safe area so experimental geometry cannot
place an actionable item beyond the layer surface.

## Theme schema

`schemaVersion` is `1`. Required tokens are `background`, `primary`, and `text`;
optional tokens are `surface`, `surfaceContainer`, `secondary`, `tertiary`,
`outline`, `textMuted`, and `error`. Colors are `#RRGGBB`. Opacity remains
separate launcher configuration. Invalid updates retain the last valid palette;
absence at startup uses built-ins.

## Execution order and risks

Phase 0 validates the pinned runtime, overlay/focus, polar drawing, one image,
IPC open/close, opacity, and live theme watching on Niri. Phase 1 validates the
dmenu contract, `img:` parsing, staged image loading, circular navigation,
mouse/keyboard selection, search, exact stdout, wallpaper integration, and
atomic matugen refresh.

Real-session risks are Niri focus policy, output choice with multiple monitors,
layer-shell input regions, WebP availability in the final closure, and FileView
watch behavior across atomic rename. Geometry and opacity remain tuneable trial
values rather than product decisions.

## Phase 2

`--applications` maps Quickshell `DesktopEntries.applications` into the common
item model and retains each `DesktopEntry` object so activation uses its
`execute()` method. `--menu NAME` loads schema-versioned JSON with nested
`submenu`, argument-array `command`, and dynamic `applications` items. Navigation
state is a stack; bindings are resolved only in the current level. Commands are
passed as argument arrays to a detached `Process`, never concatenated into a
shell command. The user menu file is watched, with the packaged example used as
the startup fallback.

## Phase 3

Structured dmenu requests use JSON Lines and preserve each original top-level
line while separating semantic display fields. A recursive `children` array
uses the same item schema and supplies arbitrary-depth navigation without any
domain-specific launcher mode. The response can select `raw`, `value`, `id`,
or normalized JSON. Invalid items return status `error`, exit code 2, and stderr
only. Provider menu items launch argument arrays through `Process`,
collect stdout/stderr through `StdioCollector`, and parse after EOF. Loading,
empty, and failure states remain navigable so Backspace can restore the parent.
Incremental streaming is intentionally deferred.

## Phase 4

Profiles provide per-use geometry/opacity overrides without duplicating QML.
Images and icons only receive a source while inside the visible arc plus a
configurable prefetch radius; Qt performs asynchronous scaled decode and keeps
the warm in-memory cache. This avoids decoding every wallpaper at menu open.
Persistent on-disk thumbnail generation remains the responsibility of the
existing wallpaper scripts.

The theme layer now offers matugen, dark, neon, and mono presets. Reduced-motion
mode drives all primary animation durations to zero. A request can select a
Quickshell screen by output name, with default-output fallback. CLI cleanup uses
`closeRequest(id)`, so interruption and timeout cannot close another caller's
session. Concurrent requests remain an explicit busy response rather than an
unsafe implicit queue.
