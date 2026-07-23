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

            brandDivider

            ScrollView {
                VStack(alignment: .leading, spacing: SFTheme.sectionSpacing) {
                    generalSection
                    remoteScriptSection
                    midiSection
                    connectionTestSection
                    aboutSection
                }
                .padding(SFTheme.padding)
            }

            if dismiss != nil {
                brandDivider

                HStack {
                    Spacer()

                    Button("閉じる") {
                        dismiss?()
                    }
                    .keyboardShortcut(.cancelAction)
                    .buttonStyle(SFSecondaryButtonStyle())
                }
                .padding(16)
            }
        }
        .frame(width: 650, height: 720)
        .background(SFTheme.background)
        .preferredColorScheme(.dark)
        .onAppear {
            remoteScriptInstaller.checkStatus()
            midi.refreshSources()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 46, height: 46)
                .clipShape(
                    RoundedRectangle(
                        cornerRadius: 10,
                        style: .continuous
                    )
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("SIGNAL FLOW Live Stopwatch")
                    .font(SFFont.title(22))
                    .foregroundColor(SFTheme.white)

                Text("Settings")
                    .font(SFFont.body(13))
                    .foregroundColor(SFTheme.white.opacity(0.56))
            }

            Spacer()
        }
        .padding(.horizontal, SFTheme.padding)
        .padding(.vertical, 19)
    }

    private var brandDivider: some View {
        Rectangle()
            .fill(SFTheme.white.opacity(0.12))
            .frame(height: 1)
    }

    // MARK: - General

    private var generalSection: some View {
        SettingsCard(title: "General") {
            BrandToggle(
                title: "常に最前面に表示",
                description: "ほかのアプリを操作しても、Live Stopwatchを手前に表示します。",
                isOn: $alwaysOnTop
            )

            BrandToggle(
                title: "STOP受信時にタイマーをリセット",
                description: "MIDI STOPを受信したとき、タイマーを00:00.0へ戻します。",
                isOn: $stopwatch.resetOnMIDIStop
            )
        }
    }

    // MARK: - Remote Script

    private var remoteScriptSection: some View {
        SettingsCard(title: "Remote Script") {
            HStack(alignment: .top, spacing: 12) {
                Circle()
                    .fill(remoteScriptStatusColor)
                    .frame(width: 11, height: 11)
                    .padding(.top, 5)

                VStack(alignment: .leading, spacing: 5) {
                    if remoteScriptInstaller.state == .installed
                        || remoteScriptInstaller.state == .success {

                        Text("インストール済み")
                            .font(SFFont.title(15))
                            .foregroundColor(SFTheme.white)

                        Text("LiveStopwatch_Clip_Watcher")
                            .font(SFFont.body(12))
                            .foregroundColor(SFTheme.white.opacity(0.60))

                        Text(SFAppInfo.versionText)
                            .font(SFFont.caption(11))
                            .foregroundColor(SFTheme.white.opacity(0.46))
                    } else {
                        Text(remoteScriptInstaller.statusMessage)
                            .font(SFFont.title(15))
                            .foregroundColor(SFTheme.white)
                    }

                    Text("Live接続中 Script：v\(midi.remoteScriptVersion)")
                        .font(SFFont.caption(11))
                        .foregroundColor(SFTheme.white.opacity(0.46))
                }

                Spacer()
            }

            HStack(spacing: 10) {
                Button("保存場所を表示") {
                    remoteScriptInstaller.revealUserLibrary()
                }
                .buttonStyle(SFSecondaryButtonStyle())

                Spacer()

                Button("再確認") {
                    remoteScriptInstaller.checkStatus()
                }
                .buttonStyle(SFSecondaryButtonStyle())

                Button(remoteScriptButtonTitle) {
                    remoteScriptInstaller.installOrUpdate()
                }
                .buttonStyle(SFPrimaryButtonStyle())
                .disabled(
                    remoteScriptInstaller.state == .checking
                        || remoteScriptInstaller.state == .installing
                        || remoteScriptInstaller.state == .installed
                )
            }

            if case .success = remoteScriptInstaller.state {
                BrandNotice(
                    text: "Ableton LiveをCommand + Qで完全終了し、再起動してください。",
                    color: .orange
                )
            }

            if case .failed(let message) = remoteScriptInstaller.state {
                BrandNotice(
                    text: message,
                    color: SFTheme.warning
                )
            }
        }
    }

    // MARK: - MIDI

    private var midiSection: some View {
        SettingsCard(title: "MIDI") {
            HStack(spacing: 10) {
                Text("入力ポート")
                    .font(SFFont.body(13))
                    .foregroundColor(SFTheme.white.opacity(0.78))
                    .frame(width: 90, alignment: .leading)

                Picker(
                    "",
                    selection: Binding(
                        get: { midi.selectedSourceID },
                        set: { midi.selectedSourceID = $0 }
                    )
                ) {
                    Text("MIDI入力を選択")
                        .tag(MIDIEndpointRef?.none)

                    ForEach(midi.sources) { source in
                        Text(source.name)
                            .tag(MIDIEndpointRef?.some(source.id))
                    }
                }
                .labelsHidden()
                .frame(maxWidth: .infinity)

                Button("接続") {
                    midi.connectSelected()
                }
                .buttonStyle(SFPrimaryButtonStyle())

                Button {
                    midi.refreshSources()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                }
                .buttonStyle(SFIconButtonStyle())
                .help("MIDI入力ポートを更新")
            }

            HStack(spacing: 9) {
                Text("状態")
                    .font(SFFont.body(13))
                    .foregroundColor(SFTheme.white.opacity(0.78))
                    .frame(width: 90, alignment: .leading)

                Circle()
                    .fill(
                        midi.connectedSourceID != nil
                            ? SFTheme.mint
                            : SFTheme.white.opacity(0.25)
                    )
                    .frame(width: 9, height: 9)

                Text(midi.connectionMessage)
                    .font(SFFont.body(12))
                    .foregroundColor(SFTheme.white.opacity(0.58))

                Spacer()
            }

            setupInstructionGroup(
                title: "IAC Driverの準備",
                lines: [
                    "Finderで［アプリケーション］→［ユーティリティ］→［Audio MIDI設定］を開きます。",
                    "メニューバーの［ウインドウ］→［MIDIスタジオを表示］を選びます。",
                    "［IAC Driver］をダブルクリックし、［装置はオンライン］にチェックします。",
                    "ポート一覧に［バス1］があることを確認します。"
                ]
            )

            setupInstructionGroup(
                title: "Ableton Liveの設定",
                lines: [
                    "Ableton Liveの［環境設定／Preferences］→［Link Tempo MIDI］を開きます。",
                    "出力ポート［IAC Driver バス1］の［Sync］をONにします。",
                    "Live Stopwatchへ戻り、入力ポートで［IAC Driver バス1］を選択します。",
                    "［接続］を押し、状態が［接続中］になることを確認します。"
                ]
            )
        }
    }

    private func setupInstructionGroup(
        title: String,
        lines: [String]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(SFFont.title(13))
                .foregroundColor(SFTheme.white.opacity(0.84))

            VStack(alignment: .leading, spacing: 7) {
                ForEach(Array(lines.enumerated()), id: \.offset) { index, line in
                    Text("\(index + 1). \(line)")
                        .font(SFFont.body(11))
                        .foregroundColor(SFTheme.white.opacity(0.48))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(.top, 2)
    }

    // MARK: - Connection Test

    private var connectionTestSection: some View {
        SettingsCard(title: "接続テスト") {
            Text("テスト開始後、Ableton Liveで再生してから停止してください。")
                .font(SFFont.body(12))
                .foregroundColor(SFTheme.white.opacity(0.52))

            HStack(spacing: 20) {
                testResult(
                    "Remote Script",
                    passed: remotePassed
                )

                testResult(
                    "MIDI START",
                    passed: startPassed
                )

                testResult(
                    "MIDI STOP",
                    passed: stopPassed
                )

                Spacer()

                Button(
                    testStartedAt == nil
                        ? "テスト開始"
                        : "再テスト"
                ) {
                    testStartedAt = Date()
                }
                .buttonStyle(SFPrimaryButtonStyle())
            }
        }
    }

    private func testResult(
        _ label: String,
        passed: Bool
    ) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(
                    passed
                        ? SFTheme.mint
                        : SFTheme.white.opacity(0.24)
                )
                .frame(width: 8, height: 8)

            Text(label)
                .font(SFFont.caption(10))
                .foregroundColor(
                    passed
                        ? SFTheme.white
                        : SFTheme.white.opacity(0.42)
                )
        }
    }

    private var startPassed: Bool {
        guard
            let began = testStartedAt,
            let received = midi.lastMIDIStartDate
        else {
            return false
        }

        return received >= began
    }

    private var stopPassed: Bool {
        guard
            let began = testStartedAt,
            let received = midi.lastMIDIStopDate
        else {
            return false
        }

        return received >= began
    }

    private var remotePassed: Bool {
        guard
            let began = testStartedAt,
            let received = midi.lastRemoteMessageDate
        else {
            return false
        }

        return received >= began
    }

    // MARK: - About

    private var aboutSection: some View {
        SFAboutCard(
            appName: "Live Stopwatch",
            appDescription:
                "Ableton Live synchronized stopwatch\nfor live show operation.",
            supportLinks: [
                SFSupportLink(
                    title: "GitHub Releases",
                    url: URL(
                        string:
                            "https://github.com/SIGNAL-FLOW-LAB/Live-Stopwatch/releases"
                    )!
                ),
                SFSupportLink(
                    title: "kobayashikantaro.com/live-stopwatch",
                    url: URL(
                        string:
                            "https://kobayashikantaro.com/live-stopwatch/"
                    )!
                )
            ]
        )
    }

    private var appVersion: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "4.0.0"
    }

    // MARK: - Remote Script Status

    private var remoteScriptButtonTitle: String {
        switch remoteScriptInstaller.state {
        case .updateAvailable:
            return "更新"

        case .installing:
            return "インストール中…"

        case .installed, .success:
            return "インストール済み"

        default:
            return "インストール"
        }
    }

    private var remoteScriptStatusColor: Color {
        switch remoteScriptInstaller.state {
        case .installed, .success:
            return SFTheme.mint

        case .updateAvailable:
            return .orange

        case .failed:
            return SFTheme.warning

        case .checking, .installing:
            return .yellow

        case .notInstalled:
            return SFTheme.white.opacity(0.28)
        }
    }
}

// MARK: - Initial Setup

struct InitialSetupView: View {
    @EnvironmentObject private var midi: MIDIController
    @EnvironmentObject private var remoteScriptInstaller: RemoteScriptInstaller

    @Binding var isPresented: Bool

    @AppStorage("HasCompletedInitialSetupV4t2")
    private var hasCompleted = false

    @State private var step = 0

    private let totalSteps = 4
    
    private func prepareStep(_ targetStep: Int) {
        switch targetStep {
        case 1:
            remoteScriptInstaller.checkStatus()

        case 3:
            midi.refreshSources()

        default:
            break
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            brandDivider

            contentArea

            brandDivider

            footer
        }
        .frame(width: 680, height: 620)
        .background(SFTheme.background)
        .onAppear {
            // 初回セットアップ画面の表示確認を優先するため、
            // 外部処理は各ステップで実行します。
        }
        
        
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 5) {
                Text("SIGNAL FLOW Live Stopwatch")
                    .font(SFFont.title(24))
                    .foregroundColor(SFTheme.white)

                Text("初回セットアップ")
                    .font(SFFont.body(14))
                    .foregroundColor(SFTheme.white.opacity(0.62))
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 7) {
                Text("STEP \(step + 1) / \(totalSteps)")
                    .font(SFFont.caption(12))
                    .foregroundColor(SFTheme.mint)

                HStack(spacing: 6) {
                    ForEach(0..<totalSteps, id: \.self) { index in
                        Capsule()
                            .fill(
                                index <= step
                                    ? SFTheme.mint
                                    : SFTheme.white.opacity(0.16)
                            )
                            .frame(width: index == step ? 26 : 12, height: 6)
                    }
                }
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 22)
    }

    // MARK: - Main Content

    private var contentArea: some View {
        Group {
            switch step {
            case 0:
                welcomeStep
            case 1:
                scriptStep
            case 2:
                abletonStep
            default:
                midiStep
            }
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .padding(26)
    }

    // MARK: - Step 1

    private var welcomeStep: some View {
        setupCard {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader(
                    title: "ライブ本番のためのストップウォッチ",
                    subtitle:
                        "Ableton Liveと連携するための初期設定を行います。"
                )

                Text(
                    "Ableton Liveの再生開始・停止、Sceneの切り替えに連動し、経過時間と曲情報を表示します。"
                )
                .font(SFFont.body(16))
                .foregroundColor(SFTheme.white.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 12) {
                    featureLine(
                        icon: "timer",
                        title: "再生・停止に完全同期"
                    )

                    featureLine(
                        icon: "music.note.list",
                        title: "Scene番号と曲名を表示"
                    )

                    featureLine(
                        icon: "rectangle.on.rectangle",
                        title: "ウィンドウ位置と設定を保存"
                    )
                }

                noticeBox(
                    text:
                        "Remote Script、Ableton Live、MIDIの順に設定します。"
                )
            }
        }
    }

    // MARK: - Step 2

    private var scriptStep: some View {
        setupCard {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader(
                    title: "Remote Scriptを準備",
                    subtitle:
                        "Scene情報をLive Stopwatchへ送信します。"
                )

                HStack(alignment: .top, spacing: 14) {
                    Circle()
                        .fill(
                            scriptReady
                                ? SFTheme.mint
                                : Color.orange
                        )
                        .frame(width: 12, height: 12)
                        .padding(.top, 4)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(remoteScriptInstaller.statusMessage)
                            .font(SFFont.title(17))
                            .foregroundColor(SFTheme.white)

                        Text("LiveStopwatch_Clip_Watcher")
                            .font(SFFont.caption(13))
                            .foregroundColor(
                                SFTheme.white.opacity(0.60)
                            )
                    }

                    Spacer()
                }

                Text(
                    "初回起動時にアプリがRemote Scriptを自動でインストールします。完了後はAbleton LiveをCommand + Qで完全終了し、再起動してください。"
                )
                .font(SFFont.body(15))
                .foregroundColor(SFTheme.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)

                if !scriptReady {
                    Button("インストール／再実行") {
                        remoteScriptInstaller.installOrUpdate()
                    }
                    .buttonStyle(SFPrimaryButtonStyle())
                } else {
                    statusConfirmation(
                        text: "Remote Scriptの準備が完了しています"
                    )
                }
            }
        }
    }

    // MARK: - Step 3

    private var abletonStep: some View {
        setupCard {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader(
                    title: "Ableton Live側を設定",
                    subtitle:
                        "Control SurfaceへRemote Scriptを登録します。"
                )

                VStack(alignment: .leading, spacing: 14) {
                    setupLine(
                        "1",
                        "Ableton Liveの環境設定／Preferencesを開く"
                    )

                    setupLine(
                        "2",
                        "Link Tempo MIDIタブを開く"
                    )

                    setupLine(
                        "3",
                        "Control Surfaceで LiveStopwatch_Clip_Watcher を選択"
                    )

                    setupLine(
                        "4",
                        "Input／Outputは None のままで構いません"
                    )
                }

                noticeBox(
                    text:
                        "設定後、Ableton Liveを再起動するとRemote Scriptが有効になります。"
                )
            }
        }
    }

    // MARK: - Step 4

    private var midiStep: some View {
        setupCard {
            VStack(alignment: .leading, spacing: 18) {
                stepHeader(
                    title: "MIDI同期を設定",
                    subtitle:
                        "Ableton Liveの再生・停止を検出します。"
                )

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 13) {
                            Color.clear
                                .frame(height: 1)
                                .id("midiTop")

                            setupLine(
                                "1",
                                "Finderで［アプリケーション］→［ユーティリティ］→［Audio MIDI設定］を開く"
                            )

                            setupLine(
                                "2",
                                "［ウインドウ］→［MIDIスタジオを表示］を選ぶ"
                            )

                            setupLine(
                                "3",
                                "［IAC Driver］を開き、［装置はオンライン］にチェックする"
                            )

                            setupLine(
                                "4",
                                "ポート一覧に［バス1］があることを確認する"
                            )

                            setupLine(
                                "5",
                                "Ableton Liveの［Link Tempo MIDI］を開く"
                            )

                            setupLine(
                                "6",
                                "出力：［IAC Driver バス1］の［Sync］をONにする"
                            )

                            setupLine(
                                "7",
                                "下の入力ポートで［IAC Driver バス1］を選び、接続する"
                            )
                        }
                    }
                    .frame(maxHeight: 235)
                    .onAppear {
                        DispatchQueue.main.async {
                            proxy.scrollTo("midiTop", anchor: .top)
                        }
                    }
                }
                .frame(maxHeight: 235)

                VStack(alignment: .leading, spacing: 10) {
                    Text("入力ポート")
                        .font(SFFont.caption(12))
                        .foregroundColor(
                            SFTheme.white.opacity(0.58)
                        )

                    HStack(spacing: 10) {
                        Picker(
                            "",
                            selection: Binding(
                                get: { midi.selectedSourceID },
                                set: { midi.selectedSourceID = $0 }
                            )
                        ) {
                            Text("MIDI入力を選択")
                                .tag(MIDIEndpointRef?.none)

                            ForEach(midi.sources) { source in
                                Text(source.name)
                                    .tag(
                                        MIDIEndpointRef?.some(
                                            source.id
                                        )
                                    )
                            }
                        }
                        .labelsHidden()
                        .frame(maxWidth: .infinity)

                        Button("更新") {
                            midi.refreshSources()
                        }
                        .buttonStyle(SFSecondaryButtonStyle())

                        Button("接続") {
                            midi.connectSelected()
                        }
                        .buttonStyle(SFPrimaryButtonStyle())
                    }

                    HStack(spacing: 8) {
                        Circle()
                            .fill(
                                midi.connectedSourceID == nil
                                    ? Color.gray
                                    : SFTheme.mint
                            )
                            .frame(width: 9, height: 9)

                        Text(midi.connectionMessage)
                            .font(SFFont.caption(13))
                            .foregroundColor(
                                midi.connectedSourceID == nil
                                    ? SFTheme.white.opacity(0.58)
                                    : SFTheme.mint
                            )
                    }
                }
            }
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if step > 0 {
                Button("戻る") {
                    step -= 1
                }
                .buttonStyle(SFSecondaryButtonStyle())
            }

            Spacer()

            if step < totalSteps - 1 {
                Button("次へ") {
                    let nextStep = step + 1
                    step = nextStep
                    prepareStep(nextStep)
                }
                .buttonStyle(SFPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            } else {
                Button("セットアップを完了") {
                    hasCompleted = true
                    isPresented = false
                }
                .buttonStyle(SFPrimaryButtonStyle())
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(.horizontal, 26)
        .padding(.vertical, 18)
    }

    // MARK: - Components

    private func stepHeader(
        title: String,
        subtitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(SFFont.title(22))
                .foregroundColor(SFTheme.white)

            Text(subtitle)
                .font(SFFont.body(14))
                .foregroundColor(
                    SFTheme.white.opacity(0.60)
                )
        }
    }

    private func featureLine(
        icon: String,
        title: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(
                    size: 16,
                    weight: .semibold
                ))
                .foregroundColor(SFTheme.mint)
                .frame(width: 24)

            Text(title)
                .font(SFFont.body(15))
                .foregroundColor(SFTheme.white)
        }
    }

    private func setupLine(
        _ number: String,
        _ text: String
    ) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text(number)
                .font(SFFont.title(13))
                .foregroundColor(SFTheme.background)
                .frame(width: 27, height: 27)
                .background(SFTheme.mint)
                .clipShape(Circle())

            Text(text)
                .font(SFFont.body(14))
                .foregroundColor(
                    SFTheme.white.opacity(0.84)
                )
                .padding(.top, 3)
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )
        }
    }

    private func noticeBox(
        text: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "info.circle.fill")
                .foregroundColor(SFTheme.mint)

            Text(text)
                .font(SFFont.caption(13))
                .foregroundColor(
                    SFTheme.white.opacity(0.70)
                )
                .fixedSize(
                    horizontal: false,
                    vertical: true
                )

            Spacer(minLength: 0)
        }
        .padding(14)
        .background(SFTheme.mint.opacity(0.09))
        .cornerRadius(10)
    }

    private func statusConfirmation(
        text: String
    ) -> some View {
        HStack(spacing: 9) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(SFTheme.mint)

            Text(text)
                .font(SFFont.body(14))
                .foregroundColor(SFTheme.mint)
        }
    }

    private func setupCard<Content: View>(
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            content()
        }
        .padding(24)
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .background(SFTheme.white.opacity(0.055))
        .overlay(
            RoundedRectangle(
                cornerRadius: 16,
                style: .continuous
            )
            .stroke(
                SFTheme.white.opacity(0.10),
                lineWidth: 1
            )
        )
        .cornerRadius(16)
    }

    private var brandDivider: some View {
        Rectangle()
            .fill(SFTheme.white.opacity(0.12))
            .frame(height: 1)
    }

    private var scriptReady: Bool {
        remoteScriptInstaller.state == .installed
            || remoteScriptInstaller.state == .success
    }
}
// MARK: - Reusable Components

private struct SettingsCard<Content: View>: View {
    let title: String
    let content: Content

    init(
        title: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(SFFont.title(16))
                .foregroundColor(SFTheme.white)

            VStack(alignment: .leading, spacing: 14) {
                content
            }
            .padding(18)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(SFTheme.white.opacity(0.055))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
            )
            .overlay(
                RoundedRectangle(
                    cornerRadius: 14,
                    style: .continuous
                )
                .stroke(
                    SFTheme.white.opacity(0.08),
                    lineWidth: 1
                )
            )
        }
    }
}



private struct BrandToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(SFFont.title(14))
                    .foregroundColor(SFTheme.white)

                Text(description)
                    .font(SFFont.body(11))
                    .foregroundColor(SFTheme.white.opacity(0.46))
            }
        }
        .toggleStyle(SwitchToggleStyle())
        .accentColor(SFTheme.mint)
    }
}

private struct BrandNotice: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(SFFont.body(12))
            .foregroundColor(color)
            .padding(10)
            .frame(
                maxWidth: .infinity,
                alignment: .leading
            )
            .background(color.opacity(0.10))
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
            )
    }
}

private struct SFPrimaryButtonStyle: ButtonStyle {
    func makeBody(
        configuration: Configuration
    ) -> some View {
        configuration.label
            .font(SFFont.title(14))
            .foregroundColor(SFTheme.background)
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            .background(
                configuration.isPressed
                    ? SFTheme.mint.opacity(0.76)
                    : SFTheme.mint
            )
            .cornerRadius(8)
    }
}

private struct SFSecondaryButtonStyle: ButtonStyle {
    func makeBody(
        configuration: Configuration
    ) -> some View {
        configuration.label
            .font(SFFont.title(14))
            .foregroundColor(SFTheme.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                configuration.isPressed
                    ? SFTheme.white.opacity(0.18)
                    : SFTheme.white.opacity(0.10)
            )
            .cornerRadius(8)
    }
}

private struct SFIconButtonStyle: ButtonStyle {
    func makeBody(
        configuration: Configuration
    ) -> some View {
        configuration.label
            .foregroundColor(SFTheme.white)
            .frame(width: 30, height: 28)
            .background(
                SFTheme.white.opacity(
                    configuration.isPressed ? 0.20 : 0.10
                )
            )
            .clipShape(
                RoundedRectangle(
                    cornerRadius: 8,
                    style: .continuous
                )
            )
    }
}

