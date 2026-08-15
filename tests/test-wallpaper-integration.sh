#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT

test_home="$test_dir/home"
mkdir -p "$test_home/.wallpapers/image" \
  "$test_home/.wallpapers/movie" \
  "$test_home/.wallpapers/waypaper_thumbnails"
touch "$test_home/.wallpapers/image/wall paper.png"
touch "$test_home/.wallpapers/movie/urls"

fake_launcher="$test_dir/kaname"
cat >"$fake_launcher" <<'FAKE'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$@" >"$KANAME_CAPTURE_DIR/arguments"
cp /dev/stdin "$KANAME_CAPTURE_DIR/menu.jsonl"
# No selection: the integration script must exit without applying anything.
FAKE
chmod +x "$fake_launcher"

HOME="$test_home" KANAME_LAUNCHER="$fake_launcher" \
  KANAME_CAPTURE_DIR="$test_dir" \
  KANAME_IMAGE_ICON="/tmp/example image.svg" \
  "$project_dir/連携スクリプト/select-wallpaper.sh"

grep -Fx -- '--jsonl' "$test_dir/arguments" >/dev/null
grep -Fx -- '--output' "$test_dir/arguments" >/dev/null
grep -Fx -- 'value' "$test_dir/arguments" >/dev/null
jq -e -s '
  length == 1
  and .[0].label == "Image"
  and .[0].icon == "/tmp/example image.svg"
  and .[0].children[0].label == "wall paper.png"
  and .[0].children[0].value == ("img:" + $home + "/.wallpapers/image/wall paper.png")
  and .[0].children[0].image == ($home + "/.wallpapers/image/wall paper.png")
' --arg home "$test_home" "$test_dir/menu.jsonl" >/dev/null

printf '%s\n' 'Wallpaper integration JSONL test passed'
