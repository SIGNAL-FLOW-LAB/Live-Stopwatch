import SwiftUI
import AppKit
import CoreMIDI

struct ContentView: View {
    @EnvironmentObject private var midi: MIDIController
    @EnvironmentObject private var stopwatch: StopwatchModel
    @EnvironmentObject private var remoteScriptInstaller: RemoteScriptInstaller
    @State private var showSettingsSheet = false
    @State private var showInitialSetup = false
    @State private var didConfigureWindow = false

    @AppStorage("AlwaysOnTop") private var alwaysOnTop = false
    @AppStorage("HasCompletedInitialSetupV3") private var hasCompletedInitialSetup = false

    var body: some View {
        GeometryReader { geometry in
            let compact =
                geometry.size.width < 650
                || geometry.size.height < 400

            VStack(spacing: 0) {
                informationBlock(
                    label: "NOW PLAYING",
                    title: currentTitle,
                    compact: compact,
                    primary: true
                )
                .frame(maxHeight: .infinity)

                divider(compact: compact)

                Text(stopwatch.formattedTime)
                    .font(.system(
                        size: timerFontSize(
                            geometry.size,
                            compact: compact
                        ),
                        weight: .heavy,
                        design: .monospaced
                    ))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.12)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                divider(compact: compact)

                informationBlock(
                    label: "SELECTED",
                    title: selectedTitle,
                    compact: compact,
                    primary: false
                )
                .frame(maxHeight: .infinity)

                divider(compact: compact)

                statusBar(compact: compact)

            }
            .background(Color.black)
        }
        .frame(minWidth: 450, minHeight: 280)
        .background(WindowAccessor { window in
            updateWindow(window)
        })
        .onChange(of: alwaysOnTop) { _ in
            updateCurrentWindow()
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView(
                dismiss: {
                    showSettingsSheet = false
                }
            )
            .environmentObject(midi)
            .environmentObject(stopwatch)
            .environmentObject(remoteScriptInstaller)
        }
        .sheet(isPresented: $showInitialSetup) {
            InitialSetupView(isPresented: $showInitialSetup)
                .environmentObject(midi)
                .environmentObject(remoteScriptInstaller)
        }
        .onAppear {
            remoteScriptInstaller.checkStatus()

            if !hasCompletedInitialSetup {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    showInitialSetup = true
                }
            }
        }
    }

    private func informationBlock(
        label: String,
        title: String,
        compact: Bool,
        primary: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: compact ? 3 : 7) {
            Text(label)
                .font(.system(
                    size: compact ? 8 : 13,
                    weight: .bold,
                    design: .monospaced
                ))
                .foregroundColor(.secondary)

            Text(title)
                .font(.system(
                    size: compact
                        ? (primary ? 17 : 14)
                        : (primary ? 31 : 24),
                    weight: primary ? .bold : .semibold
                ))
                .foregroundColor(
                    primary
                        ? .white
                        : Color.white.opacity(0.88)
                )
                .lineLimit(1)
                .minimumScaleFactor(0.4)
        }
        .frame(
            maxWidth: .infinity,
            maxHeight: .infinity,
            alignment: .leading
        )
        .padding(.horizontal, compact ? 12 : 24)
    }

    private func divider(compact: Bool) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.16))
            .frame(height: 1)
            .padding(.horizontal, compact ? 12 : 24)
    }

    private func statusBar(compact: Bool) -> some View {
        HStack(spacing: compact ? 9 : 24) {
            StatusLamp(
                label: "MIDI",
                isOn: midi.connectedSourceID != nil,
                color: .green,
                compact: compact
            )

            StatusLamp(
                label: "SCRIPT",
                isOn: midi.isRemoteScriptActive,
                color: Color(
                    red: 0.0,
                    green: 0.75,
                    blue: 0.90
                ),
                compact: compact
            )

            StatusLamp(
                label: "CLOCK",
                isOn: midi.isReceivingClock,
                color: .green,
                compact: compact
            )

            StatusLamp(
                label: "PLAY",
                isOn: stopwatch.isRunning,
                color: .green,
                compact: compact
            )

            StatusLamp(
                label: "STOP",
                isOn: !stopwatch.isRunning,
                color: .red,
                compact: compact
            )

            Spacer(minLength: 3)

            Button(action: {
                showSettingsSheet = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(
                        size: compact ? 14 : 20,
                        weight: .semibold
                    ))
                    .foregroundColor(Color.gray.opacity(0.78))
                    .frame(
                        width: compact ? 25 : 34,
                        height: compact ? 25 : 34
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, compact ? 10 : 24)
        .frame(height: compact ? 38 : 66)
    }

    private var currentTitle: String {
        guard let number = midi.currentSceneNumber else {
            return midi.currentSceneName
        }

        return String(
            format: "%02d   %@",
            number,
            midi.currentSceneName
        )
    }

    private var selectedTitle: String {
        guard let number = midi.selectedSceneNumber else {
            return midi.selectedItemName
        }

        return String(
            format: "%02d   %@",
            number,
            midi.selectedItemName
        )
    }


    private func timerFontSize(
        _ size: CGSize,
        compact: Bool
    ) -> CGFloat {
        if compact {
            return min(size.width * 0.205, size.height * 0.34)
        }

        return min(size.width * 0.215, size.height * 0.37)
    }

    private func updateWindow(_ window: NSWindow) {
        window.level = alwaysOnTop ? .floating : .normal
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: 450, height: 280)

        guard !didConfigureWindow else { return }
        didConfigureWindow = true

        // SwiftUI applies its default window size shortly after the view first
        // appears. Restore after that pass, then observe move/resize events.
        // This avoids the old behavior where the saved frame appeared briefly
        // and was immediately replaced by the minimum-size centered window.
        MainWindowFrameStore.shared.attach(to: window)
    }

    private func updateCurrentWindow() {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first else {
            return
        }

        updateWindow(window)
    }
}

private struct StatusLamp: View {
    let label: String
    let isOn: Bool
    let color: Color
    let compact: Bool

    var body: some View {
        HStack(spacing: compact ? 3 : 7) {
            Circle()
                .fill(
                    isOn
                        ? color
                        : Color.gray.opacity(0.35)
                )
                .frame(
                    width: compact ? 8 : 13,
                    height: compact ? 8 : 13
                )

            if !compact {
                Text(label)
                    .font(.system(
                        size: 12,
                        weight: .bold,
                        design: .monospaced
                    ))
                    .foregroundColor(
                        isOn ? .white : .gray
                    )
            }
        }
    }
}

private struct StageButtonStyle: ButtonStyle {
    let compact: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(
                size: compact ? 9 : 13,
                weight: .bold
            ))
            .foregroundColor(.white)
            .padding(.horizontal, compact ? 8 : 15)
            .padding(.vertical, compact ? 6 : 9)
            .background(
                configuration.isPressed
                    ? Color.gray.opacity(0.65)
                    : Color.white.opacity(0.14)
            )
            .cornerRadius(7)
    }
}

private final class MainWindowFrameStore {
    static let shared = MainWindowFrameStore()

    private let defaults = UserDefaults.standard
    private let frameKey = "LiveStopwatch.MainWindowFrame.v2"
    private weak var observedWindow: NSWindow?
    private var observers: [NSObjectProtocol] = []
    private var isRestoring = false

    private init() {}

    func attach(to window: NSWindow) {
        guard observedWindow !== window else { return }
        stopObserving()
        observedWindow = window

        // Wait until WindowGroup has finished applying its own initial frame.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self, weak window] in
            guard let self = self, let window = window else { return }
            self.restore(window)
            self.startObserving(window)
        }
    }

    private func restore(_ window: NSWindow) {
        isRestoring = true
        defer { isRestoring = false }

        if let value = defaults.string(forKey: frameKey) {
            let savedFrame = NSRectFromString(value)
            if savedFrame.width >= 450,
               savedFrame.height >= 280,
               isVisibleOnAnyScreen(savedFrame) {
                window.setFrame(savedFrame, display: true)
                return
            }
        }

        window.setContentSize(NSSize(width: 450, height: 280))
        window.center()
        save(window)
    }

    private func startObserving(_ window: NSWindow) {
        let center = NotificationCenter.default
        observers.append(center.addObserver(
            forName: NSWindow.didMoveNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            guard let self = self, let window = window else { return }
            self.save(window)
        })
        observers.append(center.addObserver(
            forName: NSWindow.didResizeNotification,
            object: window,
            queue: .main
        ) { [weak self, weak window] _ in
            guard let self = self, let window = window else { return }
            self.save(window)
        })
        observers.append(center.addObserver(
            forName: NSApplication.willTerminateNotification,
            object: nil,
            queue: .main
        ) { [weak self, weak window] _ in
            guard let self = self, let window = window else { return }
            self.save(window)
        })
    }

    private func save(_ window: NSWindow) {
        guard !isRestoring else { return }
        defaults.set(NSStringFromRect(window.frame), forKey: frameKey)
    }

    private func isVisibleOnAnyScreen(_ frame: NSRect) -> Bool {
        NSScreen.screens.contains { screen in
            screen.visibleFrame.intersection(frame).width >= 80
                && screen.visibleFrame.intersection(frame).height >= 80
        }
    }

    private func stopObserving() {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }
}

private struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()

        DispatchQueue.main.async {
            if let window = view.window {
                callback(window)
            }
        }

        return view
    }

    func updateNSView(
        _ nsView: NSView,
        context: Context
    ) {
        DispatchQueue.main.async {
            if let window = nsView.window {
                callback(window)
            }
        }
    }
}
