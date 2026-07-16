import SwiftUI

struct RemoteScriptSetupView: View {
    @ObservedObject var installer: RemoteScriptInstaller
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 34))
                    .foregroundColor(Color(red: 0.0, green: 0.75, blue: 0.90))
                VStack(alignment: .leading, spacing: 3) {
                    Text("Remote Script セットアップ").font(.title2).fontWeight(.bold)
                    Text("ターミナルを使わず、アプリ内だけでインストールします").foregroundColor(.secondary)
                }
            }
            Divider()
            Text(installer.statusMessage)
            Text(installer.installedPath)
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.secondary)
            if case .success = installer.state {
                Text("Ableton LiveをCommand + Qで完全終了し、再起動してください。")
                    .fontWeight(.semibold).foregroundColor(.orange)
            }
            Spacer()
            HStack {
                Button("保存場所を表示") { installer.revealUserLibrary() }
                Spacer()
                Button("後で") { dismiss() }
                Button(primaryButtonTitle) {
                    installer.installOrUpdate()
                }
                    .disabled(installer.state == .installing || installer.state == .checking || installer.state == .installed)
            }
        }
        .padding(24)
        .frame(width: 560, height: 300)
        .onAppear { installer.checkStatus() }
    }

    private var primaryButtonTitle: String {
        switch installer.state {
        case .updateAvailable: return "更新"
        case .installed, .success: return "インストール済み"
        default: return "インストール"
        }
    }
}
