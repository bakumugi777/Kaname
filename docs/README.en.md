# Kaname

Kaname is a fan-shaped launcher for Niri built with Quickshell. It opens from
the bottom-right corner and can display applications, user-defined menus, and
candidates supplied through standard input.

This is a personal application built for the author's own NixOS/Niri setup. It
is published as-is, without a promise of ongoing maintenance, compatibility
with other environments, or responses to feature requests. You are welcome to
use and adapt it for your own environment, subject to the repository's license.

The main Japanese README is [../README.md](../README.md). Detailed English
configuration documentation is available in
[CONFIGURATION.en.txt](CONFIGURATION.en.txt).
Runtime, Niri autostart, standalone, and embedded setups are covered in
[RUNNING.en.md](RUNNING.en.md).

## Features

- Categorized XDG desktop-entry launcher
- Ten most recently launched applications, tracked through Kaname
- dmenu-compatible line input and exact stdout selection
- Arbitrarily nested JSON Lines menus with icons, images, and descriptions
- JSON configuration for menus, geometry, opacity, keys, and profiles
- Live matugen palette updates without restarting Quickshell
- Bottom-right layer-shell overlay for Niri

Kaname does not apply wallpapers, play videos, download files, or create
thumbnails. Those operations belong to the script which invokes the launcher.

## Supported environment

- NixOS
- Niri / Wayland
- Quickshell 0.3.0, pinned by `flake.lock`
- `x86_64-linux` or `aarch64-linux`

Other compositors and Quickshell versions are not supported or guaranteed.

## Install from GitHub

Replace `OWNER` with the GitHub account that hosts the repository.

### Installer script

On a Linux system with Nix already installed:

```bash
git clone https://github.com/OWNER/kaname.git
cd kaname
./install.sh
```

The script installs Kaname into the current Nix profile and copies initial
configuration files only when they do not already exist. It never installs Nix
itself or silently overwrites your configuration.

```bash
./install.sh --help
./install.sh --no-config
./install.sh --refresh    # back up existing files as .bak and replace them
./install.sh --source github:OWNER/kaname
```

Environments other than NixOS/Niri are untested and unsupported.

### Experimental installation without Nix

After installing Quickshell 0.3.0 and Qt 6 through your distribution, run:

```bash
./install-non-nix.sh
```

It installs into `~/.local/lib/kaname` and `~/.local/bin` by default. It does
not use sudo or install system dependencies.

```bash
./install-non-nix.sh --help
./install-non-nix.sh --prefix "$HOME/.local"
./install-non-nix.sh --no-config
./install-non-nix.sh --refresh
```

Your distribution's Qt 6 image-format plugins may also be required. Package
names differ between distributions, so dependency installation is deliberately
left to the user. This installation method is experimental and unsupported.

### Direct Nix commands

```bash
nix run github:OWNER/kaname#kaname -- --applications
```

To install it into a Nix profile:

```bash
nix profile install github:OWNER/kaname#kaname
kaname --applications
```

Home Manager flake input:

```nix
{
  inputs.kaname.url = "github:OWNER/kaname";
}
```

Home Manager module:

```nix
{ inputs, pkgs, ... }:
let
  kanamePackage = inputs.kaname.packages.${pkgs.system}.default;
in {
  home.packages = [ kanamePackage ];

  xdg.configFile."kaname/config.json".source =
    "${kanamePackage}/share/kaname/config/default.json";
  xdg.configFile."kaname/menus.json".source =
    "${kanamePackage}/share/kaname/config/menus.json";

  systemd.user.services.kaname = {
    Unit = {
      Description = "Kaname Quickshell launcher";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${kanamePackage}/bin/kaname-shell";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
```

The CLI starts Quickshell automatically when needed. Running `kaname-shell` as
a user service reduces first-open latency.

## Standalone and embedded use

See [RUNNING.en.md](RUNNING.en.md) for complete Niri, systemd, lifecycle, and
shutdown instructions.

Kaname supports both a dedicated Quickshell instance and a component embedded
in an existing shared shell.

### Standalone

```bash
kaname-shell
kaname --applications
```

The bundled `shell.qml` is a minimal entry point:

```qml
import Quickshell

ShellRoot {
    Kaname {}
}
```

### Embedded in a shared shell

Arrange the shared configuration as follows:

```text
~/.config/quickshell/shared/
├── shell.qml
└── Kaname/       the package's quickshell directory
```

Shared `shell.qml`:

```qml
import Quickshell
import "Kaname" as KanameModule

ShellRoot {
    KanameModule.Kaname {}
    // MyPanel {}
    // MyNotificationCenter {}
}
```

Home Manager can place the component directory in the shared configuration:

```nix
xdg.configFile."quickshell/shared/Kaname".source =
  "${kanamePackage}/share/kaname/quickshell";
```

Start the shared shell and point the CLI at the same configuration path:

```bash
quickshell -p "$HOME/.config/quickshell/shared" --daemonize
KANAME_QML_DIR="$HOME/.config/quickshell/shared" kaname --applications
```

Set `KANAME_QML_DIR` in the launcher script or session environment if you do
not want to repeat it. Do not run the standalone `kaname-shell` service at the
same time: two Kaname components with the same IPC target make the CLI endpoint
ambiguous.

A runnable checkout example is provided at `examples/shared-shell`. Prepare its
local module link before starting it:

```bash
ln -s ../../quickshell examples/shared-shell/Kaname
quickshell -p "$PWD/examples/shared-shell" --daemonize
KANAME_QML_DIR="$PWD/examples/shared-shell" ./bin/kaname --applications
```

## Usage

Application launcher:

```bash
kaname --applications
```

Plain line input:

```bash
printf '%s\n' Alpha Beta Gamma | kaname --dmenu --prompt 'Select'
```

The selected original line is written to stdout. Cancellation writes nothing
and exits with status 1.

Image candidates:

```bash
find "$HOME/Pictures/Wallpapers" -type f -print |
  sed 's|^|img:|' |
  kaname --dmenu --profile preview --prompt 'Wallpaper'
```

Kaname returns the original `img:` line. The calling script remains responsible
for changing the wallpaper.

Nested JSON Lines input:

```bash
printf '%s\n' \
  '{"id":"tools","label":"Tools","icon":"applications-utilities","children":[{"id":"term","label":"Terminal","icon":"utilities-terminal","value":"foot"}]}' |
  kaname --jsonl --output value --prompt 'Menu'
```

Configured menu:

```bash
kaname --menu main
```

CLI syntax:

```text
kaname (--dmenu [--jsonl] [--output raw|value|id|json]
        [--prompt TEXT] [--profile NAME]
        | --applications
        | --menu NAME)
       [--screen NAME]
```

## Controls

- `Up` / `Down`: move selection
- `Enter`: activate or enter the selected child level
- `Left`: enter a child level by default
- `Right` / `Backspace`: return to the parent level
- Text input: search
- `Escape`: clear search, or close the launcher when not searching
- Mouse wheel: move selection
- Click: select or activate

The additional hierarchy keys can be changed under
`behavior.keyBindings` in `config.json`.

## Configuration

```text
~/.config/kaname/config.json          appearance, behavior, app categories
~/.config/kaname/menus.json           user-defined menus
~/.cache/matugen/kaname-colors.json   generated matugen palette
```

Both configuration files are watched while Kaname runs. A valid update is
normally applied without restarting Quickshell. See
[CONFIGURATION.en.txt](CONFIGURATION.en.txt) for every field, menu examples,
JSON Lines, profiles, and the matugen schema.

If Home Manager links the bundled files directly from the Nix store, they are
read-only. Copy them to ordinary files or generate their contents from your
Home Manager configuration when you want to edit them.

Kaname uses the icon theme selected by the Qt/desktop environment. It does not
bundle or force a particular icon theme.

## matugen

The package supplies:

```text
$package/share/kaname/matugen/kaname-colors.json.template
```

Use it to generate:

```text
~/.cache/matugen/kaname-colors.json
```

Kaname watches the output and applies valid palette updates without restarting
Quickshell. Missing or malformed palette files fall back to built-in colors.
Kaname does not change existing pywal configuration.

## Development and diagnostics

```bash
git clone https://github.com/OWNER/kaname.git
cd kaname
nix develop
nix run . -- --applications
nix build .#kaname
```

Useful checks:

```bash
bash tests/test-cli.sh
bash tests/test-wallpaper-integration.sh
shellcheck bin/kaname tests/*.sh
qmllint quickshell/*.qml
```

Known limitations:

- Only one interactive request is accepted at a time.
- Providers display candidates after stdout reaches EOF.
- Desktop applications depend on the entries visible to Quickshell.
- There is no custom wrapper for unusual `Terminal=true` desktop entries.
- Visual behavior, focus, image codecs, and icon themes require testing in a
  real Niri session.

This project is provided as-is. Environment-specific troubleshooting and
feature requests may not receive a response.

## AI-assisted development

Kaname was created with the assistance of AI. The author directed its design,
features, and behavior and tested and adjusted it in the target environment,
while using AI to help produce and revise source code and documentation.

## License

Kaname is released under the [MIT License](../LICENSE).

Copyright (c) 2026 爆裂麦茶bakumugi
