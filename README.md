# dotfiles

自分用の dotfiles 管理リポジトリ。`bin/dots`（zsh 製の自作ツール）で、
このリポジトリ内の実ファイルとホーム側の設定ファイルをシンボリックリンクで
結びつけて管理する。

## 方針

このリポジトリに置くのは**設定ファイルそのものだけ**。プラグインやテーマ、
言語のパッケージといったモジュール類は置かない（それらは各ツールのプラグ
インマネージャなどに任せる）。

## セットアップ

```sh
export DOTS_DIR="$HOME/path/to/dotfiles"
export PATH="$DOTS_DIR/bin:$PATH"
```

を `~/.zshenv` などに追加し、新しいシェルを開く。`DOTS_DIR` が未設定の場合、
`dots` は自分自身の実体（`bin/dots`）の親ディレクトリを `DOTS_DIR` として使う。

初めて使うときは:

```sh
dots init      # dots.conf を作成
dots deploy    # dots.conf に従ってシンボリックリンクを展開
```

## 仕組み

`dots.conf` は INI 風の設定ファイルで、セクションごとにグループ分けする。

```ini
[zsh]
.zshrc = ~/.zshrc

[ghostty]
config = ~/.config/ghostty/config
```

- セクション名 = リポジトリ直下のディレクトリ名（グループ名）
- `filename = target_path` の `filename` はリポジトリ内（`<セクション>/<filename>`）
  の実ファイル名、`target_path` はそのファイルをリンクするホーム側のパス

`dots deploy` を実行すると、`target_path` からリポジトリ内の実ファイルへの
シンボリックリンクが張られる。実体は常にリポジトリ側にあり、ホーム側は
リンクのみになる。

## コマンド

```
dots init                          dots.conf を初期化する
dots deploy                        dots.conf に従ってシンボリックリンクを展開する
dots join <name> <path>            既存のファイルを管理対象に追加する
dots leave <name> <file>           ファイルを管理対象から外し、実体を元の場所に戻す
dots list                          管理中のファイルを一覧表示する
dots status                        シンボリックリンクの状態を確認する
dots rename <name> <old> <new>     リポジトリ内のファイル名を変更する
```

それぞれ `dots <command> --help` で詳細を確認できる。

### dots join

すでにホームディレクトリにある設定ファイルを管理対象に加える。

```sh
dots join zsh ~/.zshrc
```

指定したファイルをリポジトリの `<name>/` ディレクトリにコピーし、元の
場所はコピー先へのシンボリックリンクに置き換えたうえで、`dots.conf` に
エントリを追記する。

### dots deploy

`dots.conf` の内容に従って、ホーム側にシンボリックリンクを展開する。
ターゲットにすでに何かファイルが存在する場合は、次のいずれかを選ぶ
プロンプトが出る。

```
[1] Backup target and overwrite with repository file (default)
[2] Overwrite target with repository file
[3] Overwrite repository file with current target
[4] Skip this file
```

### dots status

各エントリについて、正しくリンクされているか（✅）、リンクが欠けて
いるか（❌）、競合が起きているか（⚠️）を表示する。

## 開発環境

macOS + zsh を主な動作環境として作っている（将来的に Linux にも対応したい）。

## テスト

`dots.conf` のパース・書き換え処理（`parse_config` / `add_config_entry` /
`remove_config_entry` / `cleanup_empty_sections`）について、一時ディレクトリ
を使った回帰テストを用意している。

```sh
zsh tests/run_tests.zsh
```
