import SwiftUI
import AppKit
import CoreMIDI

struct SettingsView: View {
    @EnvironmentObject private var midi: MIDIController
    @EnvironmentObject private var stopwatch: StopwatchModel
    @EnvironmentObject private var remoteScriptInstaller:
        RemoteScriptInstaller

    @AppStorage("AlwaysOnTop") private var alwaysOnTop = false

    /// Non-nil when displayed as a sheet from the main window.
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
                    aboutSection
                }
                .padding(24)
            }

            if dismiss != nil {
                Divider()

                HStack {
                    Spacer()

                    Button("閉じる") {
                        dismiss?()
                    }
                    .keyboardShortcut(.cancelAction)
                }
                .padding(16)
            }
        }
        .frame(width: 620, height: 620)
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
                        .font(.system(
                            size: 11,
                            design: .monospaced
                        ))
                        .foregroundColor(.secondary)
                        .lineLimit(2)

                    Text(
                        "Live接続中 Script：v\(midi.remoteScriptVersion)"
                    )
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

                Button("再確認") {
                    remoteScriptInstaller.checkStatus()
                }

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
                Text(
                    "Ableton LiveをCommand + Qで完全終了し、"
                    + "再起動してください。"
                )
                .fontWeight(.semibold)
                .foregroundColor(.orange)
            }

            if case .failed(let message) =
                remoteScriptInstaller.state {
                Text(message)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }

    private var midiSection: some View {
        SettingsCard(title: "MIDI") {
            HStack {
                Text("入力ポート")
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
                            .tag(
                                MIDIEndpointRef?.some(source.id)
                            )
                    }
                }
                .labelsHidden()

                Button("接続") {
                    midi.connectSelected()
                }

                Button(action: {
                    midi.refreshSources()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
            }

            HStack {
                Text("状態")
                    .frame(width: 90, alignment: .leading)

                Circle()
                    .fill(
                        midi.connectedSourceID != nil
                            ? Color.green
                            : Color.gray
                    )
                    .frame(width: 10, height: 10)

                Text(midi.connectionMessage)
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
    }

    private var aboutSection: some View {
        SettingsCard(title: "About") {
            HStack {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Live Stopwatch")
                    .fontWeight(.semibold)

                    Text("Version 3.0 RC1.1")
                        .foregroundColor(.secondary)

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
            return .green
        case .updateAvailable:
            return .orange
        case .failed:
            return .red
        case .checking, .installing:
            return .yellow
        case .notInstalled:
            return .gray
        }
    }
}

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
        VStack(alignment: .leading, spacing: 14) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                content
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.06))
            .cornerRadius(10)
        }
    }
}
