import SwiftUI

@main
struct AbletonLiveStopwatchApp: App {
    @StateObject private var midiController = MIDIController()
    @StateObject private var stopwatch = StopwatchModel()
    @StateObject private var remoteScriptInstaller =
        RemoteScriptInstaller()

    var body: some Scene {
        WindowGroup("Live Stopwatch") {
            ContentView()
                .environmentObject(midiController)
                .environmentObject(stopwatch)
                .environmentObject(remoteScriptInstaller)
                .onAppear {
                    midiController.stopwatch = stopwatch
                    midiController.start()
                    remoteScriptInstaller.checkStatus()
                }
                .onDisappear {
                    midiController.shutdown()
                }
        }

        Settings {
            SettingsView(dismiss: nil)
                .environmentObject(midiController)
                .environmentObject(stopwatch)
                .environmentObject(remoteScriptInstaller)
        }
    }
}
