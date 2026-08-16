# Kaname（要）

Kanameは、[Quickshell](https://quickshell.org/)で動作するNiri向けの扇形ランチャーです。
画面右下から広がるUIで、アプリケーション、ユーザー定義メニュー、標準入力から渡した
候補を選択できます。

これは作者が自分のNixOS/Niri環境のために制作した個人用アプリケーションです。
現状のまま公開し、継続的なメンテナンス、環境ごとの動作保証、機能要望への対応は
約束しません。それでも試してみたい方は、ご自身の環境に合わせて自由に利用・改変して
ください。不具合を調査するときは、まず本書の「制約とトラブルシューティング」を
確認してください。

English documentation: [docs/README.en.md](docs/README.en.md)

実行方式、Niri常駐、単独版と共有版の詳細は
[Kaname実行ガイド](docs/RUNNING.ja.md)を参照してください。

## 主な機能

- XDG Desktop Entryを分類して表示するアプリランチャー
- Kanameから直近に起動した10アプリの履歴
- `--dmenu`によるwofi/dmenu風の標準入出力連携
- JSON Linesによる任意深さの階層メニュー、画像、アイコン、説明文
- JSON設定によるメニュー、形状、透明度、キーバインド、プロファイルの変更
- matugen生成色の監視と、Quickshellを再起動しないテーマ反映
- Niriのlayer-shell上に表示する右下オーバーレイ

Kaname自身は壁紙の探索・適用、動画再生、ダウンロード、サムネイル生成を行いません。
外部スクリプトから候補を受け取り、選択結果を返す汎用ランチャーです。

## 対象環境

- NixOS
- Niri / Wayland
- Quickshell 0.3.0（`flake.lock`が実行環境を固定）
- `x86_64-linux`または`aarch64-linux`

主な検証対象は作者のNixOS/Niri環境です。他のWaylandコンポジタやQuickshellの
別バージョンは動作保証外です。

## GitHubからインストール

以下の`OWNER`は、公開したGitHubアカウント名へ置き換えてください。

### 推奨: flakeから導入

Kanameの標準的な導入方法は、GitHub上のflakeをNixOSまたはHome Managerから
直接参照する方法です。`flake.lock`により、Kanameが使用するQuickshellと依存関係も
同じ構成で解決されます。

Home Managerを使用する場合:

```nix
# flake.nix
{
  inputs.kaname.url = "github:OWNER/kaname";
}
```

```nix
# home.nix
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

反映と確認:

```bash
home-manager switch --flake .#ユーザー名
systemctl --user status kaname.service
kaname --applications
```

Home Managerを使わず、Nix profileへ直接インストールする場合:

```bash
nix profile install github:OWNER/kaname#kaname
kaname --applications
```

インストールせず一時的に試す場合:

```bash
nix run github:OWNER/kaname#kaname -- --applications
```

`kaname-shell`を常駐させていなくても、`kaname` CLIは必要に応じてQuickshellを
自動起動します。常駐サービスにすると初回表示の待ち時間を減らせます。

### 代替: インストールスクリプト

Nixを導入済みのLinuxでは、リポジトリを取得して次を実行できます。

```bash
git clone https://github.com/OWNER/kaname.git
cd kaname
./install.sh
```

スクリプトはNix profileへKanameをインストールし、まだ存在しない場合だけ
`~/.config/kaname/`へ初期設定をコピーします。既存設定は上書きしません。

```bash
./install.sh --help
./install.sh --no-config
./install.sh --refresh    # 既存設定を.bakへ退避して更新
./install.sh --source github:OWNER/kaname
```

このスクリプトも内部ではflakeをNix profileへインストールします。Nix自体は
自動インストールしません。NixOS/Niri以外は未検証であり、動作保証や個別サポートの
対象外です。

### Nixを使わない実験的インストール

Quickshell 0.3.0とQt 6をディストリビューション側で導入した後、ユーザー領域へ
インストールできます。

```bash
./install-non-nix.sh
```

既定の配置先は`~/.local/lib/kaname`と`~/.local/bin`です。`sudo`は使用せず、
システムの依存パッケージも自動導入しません。

```bash
./install-non-nix.sh --help
./install-non-nix.sh --prefix "$HOME/.local"
./install-non-nix.sh --no-config
./install-non-nix.sh --refresh
```

画像が表示されない場合は、各ディストリビューションのQt 6画像形式プラグインも必要です。
パッケージ名が異なるため、インストーラーでは自動処理しません。非Nix版は実験的であり、
Quickshell APIや依存関係の違いを含めてサポート対象外です。

## 単独起動と共通Quickshellへの組み込み

Niriの`spawn-at-startup`、systemd、常駐プロセス、終了方法を含む詳しい説明は
[Kaname実行ガイド](docs/RUNNING.ja.md)にまとめています。

Kanameは次の2方式で起動できます。

### 単独起動

`kaname-shell`は同梱の`shell.qml`を起動します。これは従来どおりの使い方です。

```bash
kaname-shell
kaname --applications
```

同梱の`shell.qml`は、組み込み可能な本体を読み込むだけの薄い入口です。

```qml
import Quickshell

ShellRoot {
    Kaname {}
}
```

### 既存のQuickshellへ組み込む

共有シェルの設定ディレクトリを、たとえば次のように構成します。

```text
~/.config/quickshell/shared/
├── shell.qml
└── Kaname/       Kanameパッケージのquickshellディレクトリ
```

共有側の`shell.qml`:

```qml
import Quickshell
import "Kaname" as KanameModule

ShellRoot {
    KanameModule.Kaname {}

    // パネル、通知など、ほかのコンポーネント
    // MyPanel {}
}
```

Home ManagerではKanameのQMLを共有設定へ配置できます。

```nix
xdg.configFile."quickshell/shared/Kaname".source =
  "${kanamePackage}/share/kaname/quickshell";
```

共有シェルを起動します。

```bash
quickshell -p "$HOME/.config/quickshell/shared" --daemonize
```

組み込み時は、`kaname` CLIにも接続先となる共有シェルのパスを渡します。

```bash
KANAME_QML_DIR="$HOME/.config/quickshell/shared" kaname --applications
```

毎回指定したくない場合は、Niriのキーバインド用スクリプトまたはシェル環境へ
`KANAME_QML_DIR`を設定してください。共有シェルをsystemdで常駐させている場合、
Kaname専用の`kaname-shell`サービスは同時に起動しないでください。同じIPC targetを
持つKanameを2つ起動すると、CLIの接続先が曖昧になります。

リポジトリ内の最小例は次で確認できます。

```bash
ln -s ../../quickshell examples/shared-shell/Kaname
quickshell -p "$PWD/examples/shared-shell" --daemonize
KANAME_QML_DIR="$PWD/examples/shared-shell" ./bin/kaname --applications
```

詳細は[共有シェルのサンプル](examples/shared-shell/README.md)を参照してください。

## 基本的な使い方

アプリケーション一覧:

```bash
kaname --applications
```

1行1候補のdmenu入力:

```bash
printf '%s\n' Alpha Beta Gamma | kaname --dmenu --prompt 'Select'
```

選択した行だけが標準出力へ返ります。キャンセル時は何も出力せず終了コード1です。

画像候補は`img:`を付けても表示できます。

```bash
find "$HOME/Pictures/Wallpapers" -type f -print |
  sed 's|^|img:|' |
  kaname --dmenu --profile preview --prompt 'Wallpaper'
```

Kanameは選択した元の`img:`行を返すだけです。実際の壁紙変更は呼び出し元の
スクリプトで処理してください。

構造化された階層入力:

```bash
printf '%s\n' \
  '{"id":"tools","label":"Tools","icon":"applications-utilities","children":[{"id":"term","label":"Terminal","icon":"utilities-terminal","value":"foot"}]}' |
  kaname --jsonl --output value --prompt 'Menu'
```

ユーザー定義メニュー:

```bash
kaname --menu main
```

利用可能な全オプション:

```text
kaname (--dmenu [--jsonl] [--output raw|value|id|json]
        [--prompt TEXT] [--profile NAME]
        | --applications
        | --menu NAME)
       [--screen NAME]
```

## 操作

- `Up` / `Down`: 選択移動
- `Enter`: 選択、または子階層へ進む
- `Left`: 子階層へ進む（既定、設定変更可能）
- `Right` / `Backspace`: 親階層へ戻る
- 文字入力: 検索
- `Escape`: 検索を解除。検索中でなければ、どの階層からでも終了
- マウスホイール: 選択移動
- クリック: 選択または実行

左右キーは`config.json`の`behavior.keyBindings`で変更できます。

## 設定

利用者が編集するファイルは次のとおりです。

```text
~/.config/kaname/config.json   外観、動作、アプリ分類、プロファイル
~/.config/kaname/menus.json    ユーザー定義メニュー
~/.cache/matugen/kaname-colors.json  matugenが生成する配色
```

初期ファイルをパッケージからコピーする場合:

```bash
mkdir -p ~/.config/kaname
cp "$(nix build --no-link --print-out-paths github:OWNER/kaname#kaname)/share/kaname/config/default.json" \
  ~/.config/kaname/config.json
cp "$(nix build --no-link --print-out-paths github:OWNER/kaname#kaname)/share/kaname/config/menus.json" \
  ~/.config/kaname/menus.json
```

Home Managerの`xdg.configFile`で同梱設定を直接参照すると、そのファイルはNix storeへの
シンボリックリンクになります。自分で編集したい場合は、設定内容をhome.nixに生成するか、
通常ファイルとしてコピーしてください。

詳しいフィールド、メニュー例、JSON Lines、matugenテンプレートについては
[日本語設定ガイド](docs/CONFIGURATION.ja.txt)を参照してください。

## matugen連携

同梱テンプレートは次にあります。

```text
$package/share/kaname/matugen/kaname-colors.json.template
```

このテンプレートから次のJSONを生成してください。

```text
~/.cache/matugen/kaname-colors.json
```

Kanameはファイルを監視し、正常なJSONへの更新をQuickshellの再起動なしで反映します。
ファイルが存在しない場合や内容が不正な場合は内蔵色を使用し、実行は継続します。
既存のpywal設定には干渉しません。詳しいスキーマとテンプレート例は
[日本語設定ガイド](docs/CONFIGURATION.ja.txt)の「matugenテーマJSON」を参照してください。

## アイコンテーマ

Kanameは専用アイコンテーマを固定せず、Qt/デスクトップ環境が選択しているテーマを
利用します。desktop entryにアイコンがない場合やテーマ内に該当アイコンがない場合は、
フォールバックアイコンを表示します。NixOS/Home Manager側のGTK・Qtアイコンテーマ設定が
実セッションへ正しく反映されている必要があります。

## ローカル開発

```bash
git clone https://github.com/OWNER/kaname.git
cd kaname
nix develop
nix run . -- --applications
```

確認コマンド:

```bash
bash tests/test-cli.sh
bash tests/test-wallpaper-integration.sh
shellcheck bin/kaname tests/*.sh
qmllint quickshell/*.qml
nix build .#kaname
```

Wayland/Niri上の表示、フォーカス、アイコンテーマ、画像形式は実セッションでの確認も
必要です。内部設計とIPCについては[docs/IMPLEMENTATION.md](docs/IMPLEMENTATION.md)を
参照してください。

## 制約とトラブルシューティング

- 同時に複数の対話要求は処理せず、後から来た要求へbusyを返します。
- providerはstdoutのEOFを受け取ってから候補を表示します。
- `--applications`はQuickshellが取得したXDG Desktop Entryを利用します。
- Recently UsedはKaname経由で起動した直近10件だけを記録します。履歴は
  `$XDG_STATE_HOME/kaname/application-usage.json`、未設定時は
  `~/.local/state/kaname/application-usage.json`へ保存されます。
- 特殊な`Terminal=true`エントリに対する独自ターミナルラッパーはありません。
- 複数モニターでは`--screen eDP-1`または`display.screen`を指定できます。

状態確認:

```bash
systemctl --user status kaname.service
jq empty ~/.config/kaname/config.json
jq empty ~/.config/kaname/menus.json
quickshell log -p "$(nix build --no-link --print-out-paths github:OWNER/kaname#kaname)/share/kaname/quickshell" -t 100
```

設定を切り分ける場合は、既存ファイルを退避して同梱の初期設定で再現するか確認して
ください。環境依存の問題に対する個別サポートは行いません。

## AI支援による開発

KanameはAIを活用して制作されています。作者が外観、機能、挙動を決定し、実環境での
確認と調整を行いながら、ソースコードやドキュメントの作成・修正にAIを使用しました。

## ライセンス

Kanameは[MIT License](LICENSE)で公開されています。

Copyright (c) 2026 爆裂麦茶bakumugi
