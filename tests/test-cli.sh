#!/usr/bin/env bash
set -euo pipefail

project_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
test_dir=$(mktemp -d)
trap 'rm -rf -- "$test_dir"' EXIT

fake_qs="$test_dir/quickshell"
cat >"$fake_qs" <<'FAKE'
#!/usr/bin/env bash
set -eu
if [[ "$1" == "ipc" ]]; then
  shift
  while [[ "$1" != "call" ]]; do shift; done
  shift 2
  function_name=$1
  shift
  if [[ "$function_name" == "openRequest" ]]; then
    candidates=$2
    result=$4
    { printf '%s\n' selected; sed -n '2p' "$candidates"; } >"$result"
  fi
  exit 0
fi
exit 1
FAKE
chmod +x "$fake_qs"

actual=$(printf '%s\n' 'first' 'img:/tmp/wall paper.webp' | \
  XDG_RUNTIME_DIR="$test_dir" KANAME_QS_BIN="$fake_qs" KANAME_NO_AUTOSTART=1 \
  "$project_dir/bin/kaname" --dmenu --prompt 'Select Image')
[[ "$actual" == 'img:/tmp/wall paper.webp' ]]

# A successful open IPC with no result writer used to wait forever. The CLI
# must leave an interactive request alone while it is active, but stop once
# Quickshell reports that it no longer owns the request.
orphan_qs="$test_dir/orphan-quickshell"
cat >"$orphan_qs" <<'FAKE'
#!/usr/bin/env bash
set -eu
if [[ "$*" == *" requestStatus "* ]]; then
  printf '%s\n' missing
fi
exit 0
FAKE
chmod +x "$orphan_qs"
if printf '%s\n' orphan | XDG_RUNTIME_DIR="$test_dir" KANAME_QS_BIN="$orphan_qs" \
    KANAME_NO_AUTOSTART=1 "$project_dir/bin/kaname" --dmenu >/dev/null 2>&1; then
  echo 'orphaned request unexpectedly succeeded' >&2
  exit 1
fi

XDG_RUNTIME_DIR="$test_dir" KANAME_QS_BIN="$fake_qs" KANAME_NO_AUTOSTART=1 \
  "$project_dir/bin/kaname" --applications --screen eDP-1
XDG_RUNTIME_DIR="$test_dir" KANAME_QS_BIN="$fake_qs" KANAME_NO_AUTOSTART=1 \
  "$project_dir/bin/kaname" --menu main

jsonl_actual=$(printf '%s\n' '{"id":"one","label":"One"}' '{"id":"two","label":"Two"}' | \
  XDG_RUNTIME_DIR="$test_dir" KANAME_QS_BIN="$fake_qs" KANAME_NO_AUTOSTART=1 \
  "$project_dir/bin/kaname" --jsonl --output raw --prompt Structured)
[[ "$jsonl_actual" == '{"id":"two","label":"Two"}' ]]

hierarchy='{"id":"media","label":"Media","icon":"folder","children":[{"label":"Preview","image":"/tmp/preview.png","value":"img:/tmp/preview.png"}]}'
hierarchy_actual=$(printf '%s\n' '{"id":"first","label":"First"}' "$hierarchy" | \
  XDG_RUNTIME_DIR="$test_dir" KANAME_QS_BIN="$fake_qs" KANAME_NO_AUTOSTART=1 \
  "$project_dir/bin/kaname" --jsonl --output raw --prompt Hierarchy)
[[ "$hierarchy_actual" == "$hierarchy" ]]

if "$project_dir/bin/kaname" --wallpaper </dev/null >/dev/null 2>&1; then
  echo 'removed wallpaper mode unexpectedly succeeded' >&2
  exit 1
fi

if "$project_dir/bin/kaname" --unknown </dev/null >/dev/null 2>&1; then
  echo 'unknown option unexpectedly succeeded' >&2
  exit 1
fi

printf '%s\n' 'CLI contract tests passed'
