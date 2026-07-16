# Changelog

## 3.0.0
- Formal release with persistent settings, window restoration, onboarding, automatic Remote Script installation, setup guidance, connection test and SIGNAL FLOW branding.


## v3.0 RC1.1

- Settings header now uses the application icon.
- MIDI START reset is now fixed app behavior and no longer configurable.
- Clarified Always on Top and MIDI STOP reset labels.
- Updated About version to 3.0 RC1.1.

## 1.0.0

- Xcode 12.4 / Swift 5.3対応プロジェクトとして再設計
- macOS 11 Deployment Target
- Intel / Apple silicon Universal Binary設定
- CoreMIDIを旧APIベースへ整理
- Remote Scriptを整理
- ソースファイルを責務ごとに分割
- コメントを追加
- 独自ライセンスを追加
- Git管理用ファイルを追加

### Remote Script naming cleanup
- Renamed the bundled and installed Remote Script to `LiveStopwatch_Clip_Watcher`.
- Renamed the Python module to `live_stopwatch_clip_watcher.py`.
- Renamed the version marker to `live_stopwatch_version.txt`.
- Removes the legacy `SIGNAL_FLOW_Clip_Watcher` folder after a successful install/update to prevent duplicate Ableton Control Surface entries.
