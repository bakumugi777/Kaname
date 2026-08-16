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

### Recommended: install from the flake

The primary installation method is to reference Kaname's GitHub flake from
NixOS or Home Manager. The locked flake resolves Kaname's Quickshell runtime
and dependencies as one reproducible package.

Home Manager flake input:

```nix
{
  inputs.kaname.url = "github:OWNER/kaname";
}
```

Home Manager configuration:

```nix
{ inputs, ... }:
{
  imports = [ inputs.kaname.homeManagerModules.default ];

  programs.kaname = {
    enable = true;

    # Only specify values that differ from the bundled defaults.
    settings.opacity.background = 0.72;
  };
}
```

The module installs the package and generates `config.json`, `menus.json`, and
the matugen template below `~/.config`. `autostart` defaults to `false`; normally
start Kaname from Niri with `spawn-at-startup "kaname-shell"`. Set it to `true`
only when a systemd user service should own the process. Keep it disabled when
embedding Kaname in another Quickshell process. Configure menus through
`programs.kaname.menus` and all other settings through
`programs.kaname.settings`.

Apply and verify the configuration:

```bash
home-manager switch --flake .#USERNAME
kaname --applications
```

Without Home Manager, install the package directly into a Nix profile:

```bash
nix profile install github:OWNER/kaname#kaname
kaname --applications
```

`nix profile install` installs only the package; it does not generate files in
your home directory. Use the Home Manager module above or `./install.sh` when
you want initial configuration to be installed automatically.

To try it without installing:

```bash
nix run github:OWNER/kaname#kaname -- --applications
```

The CLI starts Quickshell automatically when needed. Running `kaname-shell` as
a user service reduces first-open latency.

### Alternative: installer script

On a Linux system with Nix already installed:

```bash
git clone https://github.com/OWNER/kaname.git
cd kaname
./install.sh
```

The script is a wrapper around installing the flake into the current Nix
profile. It also copies initial
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

Files generated by the Home Manager module are Nix store symlinks. Configure
them with `programs.kaname.settings` and `programs.kaname.menus` instead of
editing the JSON files directly.

The module exposes these top-level options:

- `enable`: install Kaname
- `package`: select the Kaname package
- `autostart`: enable the systemd user service (default: `false`)
- `matugen.enable`: install the matugen template (default: `true`)
- `settings`: contents generated as `config.json`
- `menus`: contents generated as `menus.json`

`settings` and `menus` are free-form JSON attributes recursively merged with
the bundled defaults. Defining an array replaces that complete array. Example:

```nix
programs.kaname = {
  enable = true;

  settings = {
    geometry = {
      visibleItems = 7;
      radius = 760;
    };
    opacity = {
      background = 0.72;
      item = 0.92;
    };
    behavior = {
      animationMs = 180;
      reducedMotion = false;
      keyBindings = {
        enterLevel = "Left";
        backLevel = "Right";
      };
    };
    theme.preset = "matugen";
    display.screen = "";
  };

  menus.menus.main = {
    label = "Kaname";
    items = [
      {
        id = "terminal";
        type = "command";
        label = "Terminal";
        icon = "utilities-terminal";
        command = [ "foot" ];
      }
    ];
  };
};
```

See [CONFIGURATION.en.txt](CONFIGURATION.en.txt) and
[`config/default.json`](../config/default.json) for all supported fields.

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

### Using matugen with Home Manager

The Home Manager module installs this **input template**:

```text
~/.config/matugen/templates/kaname-colors.json
```

Kaname reads the **generated output**, not that template:

```text
~/.cache/matugen/kaname-colors.json
```

The module deliberately does not overwrite an existing
`~/.config/matugen/config.toml`, because another Home Manager definition may
already own it. Add this entry to your existing
`xdg.configFile."matugen/config.toml".text` definition:

```nix
{ config, ... }:
{
  xdg.configFile."matugen/config.toml".text = ''
    # Keep the existing [config] and [templates.*] entries.

    [templates.kaname]
    input_path = "${config.xdg.configHome}/matugen/templates/kaname-colors.json"
    output_path = "${config.xdg.cacheHome}/matugen/kaname-colors.json"
  '';
}
```

For a manually maintained `config.toml`, add the equivalent TOML:

```toml
[templates.kaname]
input_path = "~/.config/matugen/templates/kaname-colors.json"
output_path = "~/.cache/matugen/kaname-colors.json"
```

After applying Home Manager, run the matugen command normally used by your
wallpaper workflow at least once. Installing a template alone does not create
the output JSON. Verify both sides with:

```bash
ls -l ~/.config/matugen/templates/kaname-colors.json
jq . ~/.cache/matugen/kaname-colors.json
```

If only the first file exists, matugen has not run or has not loaded the
`[templates.kaname]` entry. When the second file is valid JSON, Kaname watches
it and applies later updates without restarting Quickshell.

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
