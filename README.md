# 要 (Kaname)

Quickshell 0.3.0 上で動く、Niri向け右下扇形 dmenu ランチャーの Phase
0–1 プロトタイプです。既存の壁紙探索・適用・動画処理は保持し、選択 UI
だけを置き換えます。

設定ファイルの詳細は、日本語版
[`docs/CONFIGURATION.ja.txt`](docs/CONFIGURATION.ja.txt) と英語版
[`docs/CONFIGURATION.en.txt`](docs/CONFIGURATION.en.txt)を参照してください。

## Run

```bash
nix develop
quickshell -p "$PWD/quickshell" --daemonize
printf '%s\n' Image Video | ./bin/kaname --dmenu --prompt 'Select Mode'
find ~/.wallpapers/image -type f | sed 's|^|img:|' |
  ./bin/kaname --dmenu --prompt 'Select Image'
./bin/kaname --applications
./bin/kaname --menu main
./bin/kaname-hierarchy-demo
printf '%s\n' '{"id":"one","label":"One","value":"1"}' |
  ./bin/kaname --jsonl --output value --prompt Structured
```

NiriではQuickshellをセッション起動し、任意のキーバインドから `kaname
--dmenu` を使う既存スクリプトを実行します。CLIは本体の自動起動も試みます。
パッケージ実行は `nix run . -- --dmenu --prompt Test`、NixOS/Home Manager
では `inputs.kaname.packages.${pkgs.system}.default` をパッケージへ追加します。

壁紙スクリプトは `--wallpaper` モードを使います。既存スクリプトが画像・動画の
サムネイル候補を準備してから一度だけKanameを呼び出すため、最初に `Image` / `Video`
を選び、同じオーバーレイ内の次階層で壁紙を選択できます。最後に選んだ元の `img:`
行だけを返すので、`apply-wallpaper.sh` の処理は変わりません。

matugenテンプレートを配置します。

```bash
mkdir -p ~/.config/kaname
cp matugen/kaname-colors.json.template ~/.config/kaname/
cp config/default.json ~/.config/kaname/config.json
cp config/menus.json ~/.config/kaname/menus.json
```

更新先は `~/.cache/matugen/kaname-colors.json` です。`KANAME_TEMPLATE` と
`KANAME_THEME_FILE` で上書きできます。設計は
[`docs/IMPLEMENTATION.md`](docs/IMPLEMENTATION.md)を参照してください。

## Checks

```bash
bash tests/test-cli.sh
shellcheck bin/kaname tests/test-cli.sh 連携スクリプト/select-wallpaper.sh
qmllint quickshell/*.qml
```

Wayland/Niriの表示・フォーカス、WebP、テーマ監視は実セッション確認が必要です。
`apply-wallpaper.sh` はKaname用JSON生成だけを追加し、既存のmatugen、SDDM、
ffmpeg、yt-dlp、mpv、pywal系処理を移していません。

設定を以前コピー済みの場合、リポジトリ側の新しい既定形状を試すには
`cp config/default.json ~/.config/kaname/config.json` を再実行してください。

## Phase 2 menus

`~/.config/kaname/menus.json` は実行中に監視されます。項目の `type` は
`submenu`、`command`、`applications` を使用できます。`command` は必ず
`["program", "argument"]` の配列で指定し、暗黙のシェル展開は行いません。
`key` は現在の階層だけで有効です。Escapeまたは通常時のBackspaceで親へ
戻ります。設定がない場合は同梱の `config/menus.json` を使用します。

任意深さの階層遷移を手動確認するには、設定を変更せず次を実行できます。

```bash
./bin/kaname-hierarchy-demo
```

`Level 1 · A` を選び、Enterを3回押すとLevel 4まで進みます。Escapeまたは
Backspaceを3回押すと各親階層へ戻れます。視覚表現は常に現在層と直近の親層の
2層だけですが、スタック遷移は任意深さで検証できます。

`--applications` はXDG Desktop Entryの `Categories` を使い、「ブラウザ」「設定」
「音楽」「画像・動画」「その他」「全表示」の階層へ分類します。各アプリは必ず
「全表示」からも選べます。XDGアプリはQuickshellの `DesktopEntries` から取得し、
起動には `DesktopEntry.execute()` を使用します。Quickshell 0.3.0側で扱えない特殊な
端末起動指定に対する独自ターミナルラッパーは、現段階では追加していません。

## Phase 3 providers and JSON Lines

`provider` は外部プログラムを引数配列で起動し、EOF後に候補を表示します。
`inputFormat` は `lines` または `jsonl` です。実行中はLoading、非ゼロ終了や
JSON破損時はstderrを含むエラー項目になり、Escapeで親へ戻れます。

```json
{
  "type": "provider",
  "label": "Sessions",
  "command": ["list-sessions", "--json"],
  "inputFormat": "jsonl"
}
```

JSON Linesでは `id`、`label`、`description`、`icon`、`image`、`value`、
`keywords`、`key`、`disabled`を分離できます。provider内で実行可能にする
場合は `"type":"command"` と配列 `command` を明示します。CLIの
`--output` は `raw`、`value`、`id`、`json` から選択できます。既定は入力行を
そのまま返す `raw` です。

## Phase 4 profiles, cache, and displays

`config.json` の `profiles` で用途別に `geometry` と `opacity` を上書き
できます。既定で `applications`、`wallpaper-image`、`wallpaper-video`、
`compact` を同梱し、壁紙スクリプトも対応プロファイルを指定します。

```bash
./bin/kaname --applications --screen eDP-1
printf '%s\n' A B | ./bin/kaname --dmenu --profile compact
```

`display.screen` は既定出力名、`--screen` は要求単位の上書きです。空または
未知の名前ならQuickshellの既定出力へフォールバックします。

Kanameはアイコンテーマを固定せず、Quickshell/Qtプラットフォームテーマで選択
されているシステムアイコンテーマを使います。Home Managerの
`gtk.iconTheme.name`（この環境では `candy-icons`）を変更すれば、wofiと同様に
Kanameのデスクトップエントリ・メニューアイコンも追従します。

画像とアイコンは表示範囲と前後 `cacheRadius` 件だけソースを有効化し、縮小
デコードとQtのメモリキャッシュを利用します。全候補を同時ロードしません。

```json
{
  "behavior": { "reducedMotion": false, "cacheRadius": 1 },
  "theme": { "preset": "matugen" },
  "display": { "screen": "" }
}
```

テーマプリセットは `matugen`、`dark`、`neon`、`mono` です。`matugen`だけが
監視中のテーマJSONを色源にし、他は固定プリセットになります。
`reducedMotion: true` は開閉、回転、選択、テーマ遷移を即時化します。

CLI終了・シグナル・タイムアウト時にはrequest IDを指定して閉じるため、別の
要求を誤って閉じず、オーバーレイを残しません。MVPの同時要求方針は引き続き
明示的なbusy応答です。
