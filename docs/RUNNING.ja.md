# Kaname実行ガイド

この文書では、KanameのCLI、`kaname-shell`、Quickshellプロセスの関係と、
Niriでの単独起動・組み込み利用を説明します。

## プロセスの仕組み

`kaname`は画面本体ではなく、Quickshellへ表示要求を送るCLIです。

```text
kaname --applications
        │ IPC
        ▼
Quickshellプロセス
└── Kaname.qml
    └── 必要なときだけLauncherWindowを表示
```

`kaname --applications`や`kaname --dmenu`を実行したとき、対象のQuickshellが
存在しなければ、CLIが自動的にdaemon起動します。ランチャーを閉じてもQuickshellは
終了せず、Kanameを非表示にして次のIPC要求を待ちます。

通常、短時間だけ動くプロセスは`kaname`、常駐するプロセスは`quickshell`です。

## 方式A: Kanameを単独起動する

`kaname-shell`は、Kaname専用のQuickshell構成をフォアグラウンドで起動する
ラッパーです。

```bash
kaname-shell
```

別のターミナルから表示します。

```bash
kaname --applications
```

常駐設定をしなくても、最初の`kaname`実行時に自動起動されます。ただし初回表示には
Quickshellの起動時間が加わります。ログイン時から常駐させると初回も速く表示できます。

### Niriから単独版を常駐させる

`~/.config/niri/config.kdl`へ追加します。

```kdl
spawn-at-startup "kaname-shell"

binds {
    Mod+Space { spawn "kaname" "--applications"; }
}
```

既に`binds`ブロックがある場合は、新しく重複して作らず、その中へキーバインドだけを
追加してください。変更後は次で構文を確認できます。

```bash
niri validate
```

`kaname-shell`がPATHにない場合は、Nix storeを直接書くのではなく、Home Managerで
パッケージをPATHへ追加する方法を推奨します。

### systemdユーザーサービスを使う

Home ManagerのREADME例にある`systemd.user.services.kaname`を利用できます。
異常終了時の再起動やログ確認を行いやすい方式です。

```bash
systemctl --user status kaname.service
journalctl --user -u kaname.service -b
```

Niriの`spawn-at-startup "kaname-shell"`とsystemdサービスを同時に設定しないで
ください。常駐方法はどちらか一方を選びます。

## 方式B: ほかのQML機能とQuickshellを共有する

共有シェルでは、Kaname本体を`Kaname {}`コンポーネントとして読み込みます。

```text
~/.config/quickshell/shared/
├── shell.qml
└── Kaname/
    ├── Kaname.qml
    ├── LauncherWindow.qml
    └── ...
```

`shell.qml`の例:

```qml
import Quickshell
import "Kaname" as KanameModule

ShellRoot {
    KanameModule.Kaname {}

    // 同じプロセスで動かす別コンポーネント
    // MyPanel {}
    // MyNotificationCenter {}
}
```

共有シェルでは`kaname-shell`を起動しません。共有構成そのものを起動します。

```bash
quickshell -p "$HOME/.config/quickshell/shared" --daemonize
```

KanameのCLIには、IPC接続先として同じ共有構成を指定します。

```bash
KANAME_QML_DIR="$HOME/.config/quickshell/shared" kaname --applications
```

`KANAME_QML_DIR`を指定し忘れると、CLIは単独版のKanameを別プロセスとして起動します。
メモリ共有が目的の場合は、Niriのキーバインド、ラッパースクリプト、またはセッション
環境へ必ず設定してください。

### Niriから共有版を常駐させる

`spawn-at-startup`はシェルを介さないため、`$HOME`や`~`の展開を前提にしないで
ください。実際の絶対パスへ置き換えます。

```kdl
spawn-at-startup "quickshell" "-p" "/home/USER/.config/quickshell/shared"

binds {
    Mod+Space {
        spawn "env" "KANAME_QML_DIR=/home/USER/.config/quickshell/shared" "kaname" "--applications";
    }
}
```

パス展開が必要なら、短いラッパースクリプトを`~/.local/bin`へ置き、Niriからその
スクリプトを起動する方法が分かりやすく安全です。

Home Managerで共有モジュールを配置する例:

```nix
xdg.configFile."quickshell/shared/Kaname".source =
  "${kanamePackage}/share/kaname/quickshell";

home.sessionVariables.KANAME_QML_DIR =
  "${config.xdg.configHome}/quickshell/shared";
```

共有シェルをsystemdユーザーサービスで起動する場合も、Niriの
`spawn-at-startup`とは併用しません。

## 起動状態の確認と終了

実行中のQuickshell:

```bash
quickshell list
pgrep -af quickshell
```

共有構成だけを終了:

```bash
quickshell kill -p "$HOME/.config/quickshell/shared"
```

systemdで起動した単独版を終了:

```bash
systemctl --user stop kaname.service
```

ランチャー画面をEscapeで閉じても、待機中のQuickshellプロセスは終了しません。

## どちらを選ぶか

単独版が向いている場合:

- KanameだけをQuickshellで使う
- 導入を単純にしたい
- 他のQML構成から障害を分離したい

共有版が向いている場合:

- パネル、通知、ランチャーなど複数のQML機能を作る
- Qt/Quickshellランタイムを共有して常駐メモリを抑えたい
- テーマや状態を同じシェル内で連携したい

単独版と共有版を同時に起動することは推奨しません。どちらも`kaname`というIPC
targetを公開するため、CLIの接続先管理が分かりにくくなります。

## Niri以外

KanameはNixOS/Niriで開発・検証されています。layer-shell対応の別Wayland
コンポジタでも動作する可能性はありますが、配置、フォーカス、複数画面の挙動は
保証しません。X11は対象外です。
