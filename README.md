# Live Stopwatch v3.1.0

Ableton LiveのSession Viewを本番再生に使用するPA・イベントオペレーター向けのmacOSアプリです。

## 対応方針

- Xcode 12.4
- Swift 5.3
- macOS 11 Big Sur以降
- Intel x86_64
- Apple silicon arm64
- Universal Binary
- Ableton Live 12
- IAC Driver
- SIGNAL FLOW Remote Script

## 主な機能

- Liveの再生開始でストップウォッチ開始
- Liveの停止で0リセット
- Track 1の再生クリップ変更時に0から再スタート
- Main列のScene名をNOW PLAYINGとして表示
- 選択中トラックのクリップ名をSELECTEDとして表示
- 選択スロットが空の場合はScene名を表示
- MIDI / SCRIPT / CLOCK / PLAY / STOP状態表示
- 常に最前面
- 小型ウィンドウ対応
- IAC Driver自動検出

## プロジェクト構成

```text
App/
  AbletonLiveStopwatch.xcodeproj
  AbletonLiveStopwatch/

RemoteScript/
  LiveStopwatch_Clip_Watcher/
  アプリ内の「Remote Script セットアップ」

Docs/
Release/
LICENSE.txt
.gitignore
.gitattributes
Build Universal App.command
```

## Xcode 12.4で開く

`App/AbletonLiveStopwatch.xcodeproj`を開いてください。

## Universal Appを作る

`Build Universal App.command`を実行します。

完成アプリ：

```text
Release/
Ableton Live Stopwatch by SIGNAL FLOW.app
```

## Git管理開始

このフォルダでターミナルを開き、以下を実行します。

```bash
git init
git add .
git commit -m "Initial release v1.0"
```

## 注意

このプロジェクトはXcode 12.4互換形式・Swift 5.3構文を意図して作成していますが、
こちらの環境ではXcode 12.4およびmacOS 11 Intel実機によるコンパイル検証はできていません。

初回はXcode 12.4でビルドし、表示されるエラーを修正しながら完成させる必要があります。


## v2.2

AppKit時計描画による低負荷化と、Main列選択時のSELECTED表示修正を行いました。


## v2.22

時計表示をv2.0方式へ戻し、低負荷化は10Hz更新と多重起動防止だけに限定した検証版です。


## v2.23

STOP時の停止・0リセットと、初回SELECTED表示を修正しました。

## v2.5

Remote Scriptの外部`.command`インストーラーを廃止しました。
アプリ内のセットアップ画面から、インストールと更新を行います。


## v2.6

右下の歯車から、Remote Script・MIDI・一般設定・バージョン情報をまとめた統合設定画面を開けます。


## v2.30

macOS 11／Xcode 12.4互換性を優先した安定化版です。v2.6の機能を維持し、macOS 12専用APIを削除しました。


## v2.31

トップ画面を整理し、最前面設定とRESETを削除。アプリ名、アイコン、起動サイズを変更しました。



## v3.1.0

- NOW PLAYING／SELECTEDのラベルと曲名をウィンドウサイズに合わせて拡大縮小
- フルスクリーン時にタイマーと曲情報の視認性バランスを改善
- 長い曲名の自動縮小と最小可読サイズを改善
- アプリ／Remote Scriptのバージョンを3.1.0へ統一


## v3.0.0.1

- 設定画面のアイコンをアプリアイコンへ統一
- MIDI STARTリセットを固定動作化し、設定項目を削除
- 設定文言を明確化

## v3.0.0

販売候補版です。アプリ名をLive Stopwatchへ統一し、起動後の自由なリサイズと透明背景アイコンを反映しました。


## 初回セットアップ
初回起動時にセットアップ画面が開き、Remote Scriptを自動インストールします。画面の案内に沿ってAbleton LiveのControl SurfaceとIAC Driver バス1を設定してください。

設定、MIDI入力ポート、メインウィンドウのサイズ・位置は次回起動時に復元されます。
