#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./install-non-nix.sh [OPTIONS]

Install Kaname into a user-owned prefix without Nix.

Options:
  --prefix PATH         Installation prefix (default: ~/.local)
  --no-config           Do not install initial configuration files
  --refresh             Back up existing configuration as .bak and replace it
  --skip-version-check  Allow a Quickshell version other than 0.3.0
  -h, --help            Show this help

This script does not install system dependencies or use sudo.
EOF
}

die() {
  printf 'kaname non-Nix installer: %s\n' "$*" >&2
  exit 1
}

script_dir=$(CDPATH='' cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
prefix=${HOME:?HOME is not set}/.local
install_config=1
refresh_config=0
check_version=1

while (($#)); do
  case "$1" in
    --prefix)
      (($# >= 2)) || die '--prefix requires a path'
      prefix=$2
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
    --skip-version-check)
      check_version=0
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

for command_name in bash quickshell readlink sed tail mktemp seq sleep; do
  command -v "$command_name" >/dev/null 2>&1 || die \
    "required command not found: $command_name"
done

if ((check_version)); then
  quickshell_version=$(quickshell --version 2>&1 || true)
  case "$quickshell_version" in
    *0.3.0*) ;;
    *)
      die "Quickshell 0.3.0 is required (found: ${quickshell_version:-unknown}). Use --skip-version-check at your own risk."
      ;;
  esac
fi

[[ -d "$script_dir/quickshell" ]] || die 'quickshell source directory is missing'
[[ -d "$script_dir/config" ]] || die 'config source directory is missing'
[[ -d "$script_dir/matugen" ]] || die 'matugen source directory is missing'

install_root=$prefix/lib/kaname
bin_dir=$prefix/bin
mkdir -p "$install_root" "$bin_dir"

# Replace only Kaname-owned program files. User configuration lives elsewhere.
for source_dir in quickshell config matugen; do
  rm -rf -- "${install_root:?}/$source_dir"
  cp -a -- "$script_dir/$source_dir" "$install_root/$source_dir"
done
mkdir -p "$install_root/bin"
install -m 0755 "$script_dir/bin/kaname" "$install_root/bin/kaname"
install -m 0755 "$script_dir/bin/kaname-shell" "$install_root/bin/kaname-shell"
ln -sfn -- "../lib/kaname/bin/kaname" "$bin_dir/kaname"
ln -sfn -- "../lib/kaname/bin/kaname-shell" "$bin_dir/kaname-shell"

if ((install_config)); then
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

  install_one "$install_root/config/default.json" "$config_dir/config.json"
  install_one "$install_root/config/menus.json" "$config_dir/menus.json"
  install_one "$install_root/matugen/kaname-colors.json.template" \
    "$matugen_template_dir/kaname-colors.json"
fi

cat <<EOF

Kaname was installed successfully into:

  $install_root

Ensure this directory is in PATH:

  $bin_dir

Then run:

  kaname --applications

If images do not load, install your distribution's Qt 6 image-format plugins.
The exact package name differs between distributions.
EOF
