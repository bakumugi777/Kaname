#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install.sh [OPTIONS]

Install Kaname through the Nix package manager.

Options:
  --source FLAKE  Install from this flake reference (for example,
                  github:OWNER/kaname). The default is this checkout.
  --no-config     Do not install initial configuration files.
  --refresh       Replace existing configuration files after creating .bak
                  backups. Without this option, existing files are preserved.
  -h, --help      Show this help.

Environment:
  KANAME_INSTALL_SOURCE  Default flake reference used by --source.
EOF
}

die() {
  printf 'kaname installer: %s\n' "$*" >&2
  exit 1
}

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
source_ref=${KANAME_INSTALL_SOURCE:-"path:$script_dir"}
install_config=1
refresh_config=0

while (($#)); do
  case "$1" in
    --source)
      (($# >= 2)) || die '--source requires a flake reference'
      source_ref=$2
      shift 2
      ;;
    --no-config)
      install_config=0
      shift
      ;;
    --refresh)
      refresh_config=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      die "unknown option: $1"
      ;;
  esac
done

[[ $(uname -s) == Linux ]] || die 'Kaname currently supports Linux only'
command -v nix >/dev/null 2>&1 || die \
  'Nix is required. Install it from https://nixos.org/download/ and retry.'

flake_target="${source_ref}#kaname"
printf 'Installing Kaname from %s\n' "$flake_target"

if ! nix profile install "$flake_target"; then
  cat >&2 <<'EOF'

Installation failed. If Nix reports that flakes are disabled, enable the
`nix-command` and `flakes` experimental features, then run this script again.
For a single invocation you can use:

  NIX_CONFIG='experimental-features = nix-command flakes' ./install.sh
EOF
  exit 1
fi

if ((install_config)); then
  package_path=$(nix build --no-link --print-out-paths "$flake_target")
  xdg_config_dir=${XDG_CONFIG_HOME:-"$HOME/.config"}
  config_dir=$xdg_config_dir/kaname
  matugen_template_dir=$xdg_config_dir/matugen/templates
  mkdir -p "$config_dir" "$matugen_template_dir"

  install_one() {
    local source_file=$1
    local target_file=$2
    local backup_file="$target_file.bak"

    if [[ -e "$target_file" || -L "$target_file" ]]; then
      if ((!refresh_config)); then
        printf 'Keeping existing %s\n' "$target_file"
        return
      fi
      [[ ! -e "$backup_file" && ! -L "$backup_file" ]] || die \
        "backup already exists: $backup_file"
      cp -aT -- "$target_file" "$backup_file"
      printf 'Backed up %s to %s\n' "$target_file" "$backup_file"
      rm -f -- "$target_file"
    fi

    cp -- "$source_file" "$target_file"
    chmod u+rw "$target_file"
    printf 'Installed %s\n' "$target_file"
  }

  install_one "$package_path/share/kaname/config/default.json" \
    "$config_dir/config.json"
  install_one "$package_path/share/kaname/config/menus.json" \
    "$config_dir/menus.json"
  install_one "$package_path/share/kaname/matugen/kaname-colors.json.template" \
    "$matugen_template_dir/kaname-colors.json"
fi

cat <<'EOF'

Kaname was installed successfully.

Start the application launcher with:

  kaname --applications

The CLI starts its Quickshell instance when necessary. A persistent
kaname-shell user service is optional and can reduce first-open latency.
EOF
