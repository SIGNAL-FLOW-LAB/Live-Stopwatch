import Foundation
import AppKit
import Combine

/// Installs the bundled Ableton Remote Script without launching Terminal,
/// shell scripts, AppleScript, or an external `.command` file.
///
/// The installation is performed entirely with FileManager inside the app.
final class RemoteScriptInstaller: ObservableObject {
    enum InstallState: Equatable {
        case checking
        case notInstalled
        case installed
        case updateAvailable
        case installing
        case success
        case failed(String)
    }

    @Published private(set) var state: InstallState = .checking
    @Published private(set) var installedPath = ""
    @Published private(set) var statusMessage = "確認中…"

    private let scriptFolderName = "SIGNAL_FLOW_Clip_Watcher"
    private let versionFileName = "signal_flow_version.txt"
    private let bundledVersion = "3.0"

    init() {
        checkStatus()
    }

    func checkStatus() {
        let destination = destinationURL()
        installedPath = destination.path
        state = .checking
        statusMessage = "Remote Scriptを確認しています…"

        guard FileManager.default.fileExists(
            atPath: destination.path
        ) else {
            state = .notInstalled
            statusMessage = "Remote Scriptは未インストールです。"
            return
        }

        let versionURL = destination.appendingPathComponent(
            versionFileName
        )

        let installedVersion = try? String(
            contentsOf: versionURL,
            encoding: .utf8
        ).trimmingCharacters(
            in: .whitespacesAndNewlines
        )

        if installedVersion == bundledVersion {
            state = .installed
            statusMessage =
                "Remote Script v\(bundledVersion)はインストール済みです。"
        } else {
            state = .updateAvailable
            statusMessage =
                "Remote Scriptをv\(bundledVersion)へ更新できます。"
        }
    }

    func installOrUpdate() {
        state = .installing
        statusMessage = "Remote Scriptをインストールしています…"

        do {
            let source = try bundledScriptURL()
            let destination = destinationURL()
            let parent = destination.deletingLastPathComponent()

            try FileManager.default.createDirectory(
                at: parent,
                withIntermediateDirectories: true,
                attributes: nil
            )

            // Copy to a temporary sibling folder first so a failed update
            // does not destroy the currently installed script.
            let temporary = parent.appendingPathComponent(
                ".\(scriptFolderName)-installing"
            )

            if FileManager.default.fileExists(
                atPath: temporary.path
            ) {
                try FileManager.default.removeItem(at: temporary)
            }

            try FileManager.default.copyItem(
                at: source,
                to: temporary
            )

            try bundledVersion.write(
                to: temporary.appendingPathComponent(
                    versionFileName
                ),
                atomically: true,
                encoding: .utf8
            )

            if FileManager.default.fileExists(
                atPath: destination.path
            ) {
                try FileManager.default.removeItem(at: destination)
            }

            try FileManager.default.moveItem(
                at: temporary,
                to: destination
            )

            // Ensure the Python source remains readable by Ableton Live.
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: destination.path
            )

            for fileName in [
                "__init__.py",
                "signal_flow_clip_watcher.py",
                versionFileName,
            ] {
                let fileURL = destination.appendingPathComponent(
                    fileName
                )
                try? FileManager.default.setAttributes(
                    [.posixPermissions: 0o644],
                    ofItemAtPath: fileURL.path
                )
            }

            installedPath = destination.path
            state = .success
            statusMessage =
                "インストール完了。Ableton LiveをCommand + Qで完全終了し、再起動してください。"

        } catch {
            state = .failed(error.localizedDescription)
            statusMessage =
                "インストールに失敗しました：\(error.localizedDescription)"
        }
    }

    func revealUserLibrary() {
        let parent = destinationURL().deletingLastPathComponent()

        try? FileManager.default.createDirectory(
            at: parent,
            withIntermediateDirectories: true,
            attributes: nil
        )

        NSWorkspace.shared.open(parent)
    }

    private func destinationURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Music")
            .appendingPathComponent("Ableton")
            .appendingPathComponent("User Library")
            .appendingPathComponent("Remote Scripts")
            .appendingPathComponent(scriptFolderName)
    }

    private func bundledScriptURL() throws -> URL {
        guard let resourceURL = Bundle.main.resourceURL else {
            throw installerError(
                "アプリのResourcesフォルダを取得できません。"
            )
        }

        let candidates = [
            resourceURL
                .appendingPathComponent("EmbeddedRemoteScript")
                .appendingPathComponent(scriptFolderName),

            resourceURL
                .appendingPathComponent(scriptFolderName),
        ]

        for candidate in candidates {
            let initializer = candidate.appendingPathComponent(
                "__init__.py"
            )
            let script = candidate.appendingPathComponent(
                "signal_flow_clip_watcher.py"
            )

            if FileManager.default.fileExists(
                atPath: initializer.path
            ) && FileManager.default.fileExists(
                atPath: script.path
            ) {
                return candidate
            }
        }

        throw installerError(
            "アプリ内のRemote Scriptが見つかりません。アプリを再ビルドしてください。"
        )
    }

    private func installerError(
        _ message: String
    ) -> NSError {
        NSError(
            domain: "com.signalflow.AbletonLiveStopwatch",
            code: 1001,
            userInfo: [
                NSLocalizedDescriptionKey: message
            ]
        )
    }
}
