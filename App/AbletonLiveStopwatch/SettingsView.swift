import SwiftUI
import AppKit
import CoreMIDI

struct SettingsView: View {
    @EnvironmentObject private var midi: MIDIController
    @EnvironmentObject private var stopwatch: StopwatchModel
    @EnvironmentObject private var remoteScriptInstaller: RemoteScriptInstaller

    @AppStorage("AlwaysOnTop") private var alwaysOnTop = false
    @State private var testStartedAt: Date?

    let dismiss: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    generalSection
                    remoteScriptSection
                    midiSection
                    connectionTestSection
                    aboutSection
                }
                .padding(24)
            }

            if dismiss != nil {
                Divider()
                HStack {
                    Spacer()
                    Button("閉じる") { dismiss?() }
                        .keyboardShortcut(.cancelAction)
                }
                .padding(16)
            }
        }
        .frame(width: 620, height: 690)
        .onAppear {
            remoteScriptInstaller.checkStatus()
            midi.refreshSources()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text("Live Stopwatch")
                    .font(.title2)
                    .fontWeight(.bold)
                Text("Settings")
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(20)
    }

    private var generalSection: some View {
        SettingsCard(title: "General") {
            Toggle("常に最前面に表示", isOn: $alwaysOnTop)
            Toggle(
                "STOP受信時にタイマーを0:00へ戻す",
                isOn: $stopwatch.resetOnMIDIStop
            )
        }
    }

    private var remoteScriptSection: some View {
        SettingsCard(title: "Remote Script") {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(remoteScriptStatusColor)
                    .frame(width: 12, height: 12)
                    .padding(.top, 4)

                VStack(alignment: .leading, spacing: 5) {
                    Text(remoteScriptInstaller.statusMessage)
                        .fontWeight(.semibold)
                    Text(remoteScriptInstaller.installedPath)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                    Text("Live接続中 Script：v\(midi.remoteScriptVersion)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }

            HStack {
                Button("保存場所を表示") {
                    remoteScriptInstaller.revealUserLibrary()
                }
                Spacer()
                Button("再確認") { remoteScriptInstaller.checkStatus() }
                Button(remoteScriptButtonTitle) {
                    remoteScriptInstaller.installOrUpdate()
                }
                .disabled(
                    remoteScriptInstaller.state == .checking
                    || remoteScriptInstaller.state == .installing
                    || remoteScriptInstaller.state == .installed
                )
            }

            if case .success = remoteScriptInstaller.state {
                Text("Ableton LiveをCommand + Qで完全終了し、再起動してください。")
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
            if case .failed(let message) = remoteScriptInstaller.state {
                Text(message).foregroundColor(.red).font(.caption)
            }
        }
    }

    private var midiSection: some View {
        SettingsCard(title: "MIDI") {
            HStack {
                Text("入力ポート").frame(width: 90, alignment: .leading)
                Picker("", selection: Binding(
                    get: { midi.selectedSourceID },
                    set: { midi.selectedSourceID = $0 }
                )) {
                    Text("MIDI入力を選択").tag(MIDIEndpointRef?.none)
                    ForEach(midi.sources) { source in
                        Text(source.name).tag(MIDIEndpointRef?.some(source.id))
                    }
                }
                .labelsHidden()
                Button("接続") { midi.connectSelected() }
                Button(action: { midi.refreshSources() }) {
                    Image(systemName: "arrow.clockwise")
                }
            }

            HStack {
                Text("状態").frame(width: 90, alignment: .leading)
                Circle()
                    .fill(midi.connectedSourceID != nil ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)
                Text(midi.connectionMessage).foregroundColor(.secondary)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("IAC Driverの準備")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("Finderの［アプリケーション］→［ユーティリティ］→［Audio MIDI設定］を開きます。［ウインドウ］→［MIDIスタジオを表示］を選び、［IAC Driver］をダブルクリックして［装置はオンライン］にチェックしてください。ポート一覧に［バス1］があることも確認します。")
                Text("次にAbleton Liveの［環境設定／Preferences］→［Link Tempo MIDI］で、出力：IAC Driver バス1の［Sync］をONにします。最後に、この画面の入力ポートで［IAC Driver バス1］を選び［接続］を押してください。")
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
    }

    private var connectionTestSection: some View {
        SettingsCard(title: "接続テスト") {
            Text("テスト開始後、Ableton Liveで再生してから停止してください。")
                .font(.caption)
                .foregroundColor(.secondary)

            HStack(spacing: 22) {
                testResult("Remote Script", passed: remotePassed)
                testResult("START", passed: startPassed)
                testResult("STOP", passed: stopPassed)
                Spacer()
                Button(testStartedAt == nil ? "テスト開始" : "再テスト") {
                    testStartedAt = Date()
                }
            }
        }
    }

    private func testResult(_ label: String, passed: Bool) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(passed ? Color.green : Color.gray)
                .frame(width: 9, height: 9)
            Text(label)
                .font(.caption)
                .foregroundColor(passed ? .primary : .secondary)
        }
    }

    private var startPassed: Bool {
        guard let began = testStartedAt, let received = midi.lastMIDIStartDate else { return false }
        return received >= began
    }
    private var stopPassed: Bool {
        guard let began = testStartedAt, let received = midi.lastMIDIStopDate else { return false }
        return received >= began
    }
    private var remotePassed: Bool {
        guard let began = testStartedAt, let received = midi.lastRemoteMessageDate else { return false }
        return received >= began
    }

    private var aboutSection: some View {
        SettingsCard(title: "About") {
            HStack(spacing: 16) {
                Image("BrandLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 58, height: 58)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Live Stopwatch").fontWeight(.semibold)
                    Text("Version 3.0.0").foregroundColor(.secondary)
                    Text("Copyright © 2026 SIGNAL FLOW")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
        }
    }

    private var remoteScriptButtonTitle: String {
        switch remoteScriptInstaller.state {
        case .updateAvailable: return "更新"
        case .installing: return "インストール中…"
        case .installed, .success: return "インストール済み"
        default: return "インストール"
        }
    }

    private var remoteScriptStatusColor: Color {
        switch remoteScriptInstaller.state {
        case .installed, .success: return .green
        case .updateAvailable: return .orange
        case .failed: return .red
        case .checking, .installing: return .yellow
        case .notInstalled: return .gray
        }
    }
}

struct InitialSetupView: View {
    @EnvironmentObject private var midi: MIDIController
    @EnvironmentObject private var remoteScriptInstaller: RemoteScriptInstaller
    @Binding var isPresented: Bool
    @AppStorage("HasCompletedInitialSetupV3") private var hasCompleted = false
    @State private var step = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(nsImage: NSApplication.shared.applicationIconImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 46, height: 46)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Live Stopwatchへようこそ")
                        .font(.title2).fontWeight(.bold)
                    Text("初回セットアップ  \(step + 1) / 4")
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(24)
            Divider()

            Group {
                if step == 0 { welcomeStep }
                else if step == 1 { scriptStep }
                else if step == 2 { abletonStep }
                else { midiStep }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(28)

            Divider()
            HStack {
                if step > 0 { Button("戻る") { step -= 1 } }
                Spacer()
                if step < 3 {
                    Button("次へ") { step += 1 }
                        .keyboardShortcut(.defaultAction)
                } else {
                    Button("セットアップを完了") {
                        hasCompleted = true
                        isPresented = false
                    }
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
        }
        .frame(width: 680, height: 620)
        .onAppear {
            remoteScriptInstaller.checkStatus()
            if remoteScriptInstaller.state == .notInstalled
                || remoteScriptInstaller.state == .updateAvailable {
                remoteScriptInstaller.installOrUpdate()
            }
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("ライブ本番のためのストップウォッチ")
                .font(.title3).fontWeight(.semibold)
            Text("Ableton Liveの再生開始・停止、Sceneの切り替えに連動して、経過時間と曲情報を表示します。最初にRemote ScriptとMIDIを設定します。")
                .foregroundColor(.secondary)
            Label("設定・MIDIポート・ウィンドウ位置は次回起動時も保持されます", systemImage: "checkmark.circle.fill")
        }
    }

    private var scriptStep: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Remote Script").font(.title3).fontWeight(.semibold)
            HStack(spacing: 10) {
                Circle().fill(scriptReady ? Color.green : Color.orange).frame(width: 12, height: 12)
                Text(remoteScriptInstaller.statusMessage).fontWeight(.semibold)
            }
            Text("初回起動時にアプリが自動でインストールします。完了後はAbleton LiveをCommand + Qで完全終了して再起動してください。")
                .foregroundColor(.secondary)
            if !scriptReady {
                Button("インストール／再実行") { remoteScriptInstaller.installOrUpdate() }
            }
        }
    }

    private var abletonStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ableton Live側の設定").font(.title3).fontWeight(.semibold)
            setupLine("1", "Ableton Liveの環境設定／Preferencesを開く")
            setupLine("2", "Link Tempo MIDIタブを開く")
            setupLine("3", "Control Surfaceで SIGNAL_FLOW_Clip_Watcher を選択")
            setupLine("4", "Input／Outputは None のままで構いません")
        }
    }

    private var midiStep: some View {
        VStack(alignment: .leading, spacing: 13) {
            Text("MIDIの設定").font(.title3).fontWeight(.semibold)

            setupLine("1", "Finderで［アプリケーション］→［ユーティリティ］→［Audio MIDI設定］を開く")
            setupLine("2", "メニューバーの［ウインドウ］→［MIDIスタジオを表示］を選ぶ")
            setupLine("3", "［IAC Driver］をダブルクリックし、［装置はオンライン］にチェックする")
            setupLine("4", "ポート一覧に［バス1］があることを確認する。無い場合は［＋］で追加する")
            setupLine("5", "Ableton Liveの［環境設定／Preferences］→［Link Tempo MIDI］を開く")
            setupLine("6", "MIDI Portsの出力：［IAC Driver バス1］で［Sync］をONにする")
            setupLine("7", "下の入力ポートで［IAC Driver バス1］を選び、［接続］を押す")

            HStack {
                Picker("入力ポート", selection: Binding(
                    get: { midi.selectedSourceID },
                    set: { midi.selectedSourceID = $0 }
                )) {
                    Text("MIDI入力を選択").tag(MIDIEndpointRef?.none)
                    ForEach(midi.sources) { source in
                        Text(source.name).tag(MIDIEndpointRef?.some(source.id))
                    }
                }
                Button("更新") { midi.refreshSources() }
                Button("接続") { midi.connectSelected() }
            }
            Label(midi.connectionMessage, systemImage: midi.connectedSourceID == nil ? "circle" : "checkmark.circle.fill")
                .foregroundColor(midi.connectedSourceID == nil ? .secondary : .green)
        }
    }

    private func setupLine(_ number: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(number)
                .fontWeight(.bold)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.18))
                .clipShape(Circle())
            Text(text).padding(.top, 3)
        }
    }

    private var scriptReady: Bool {
        remoteScriptInstaller.state == .installed || remoteScriptInstaller.state == .success
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let content: Content
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(title).font(.headline)
            VStack(alignment: .leading, spacing: 12) { content }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(0.06))
                .cornerRadius(10)
        }
    }
}
