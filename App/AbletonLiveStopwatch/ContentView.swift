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
            let metrics = LayoutMetrics(size: geometry.size)

            VStack(spacing: 0) {
                informationBlock(
                    label: "NOW PLAYING",
                    title: currentTitle,
                    metrics: metrics,
                    primary: true
                )
                .frame(height: metrics.informationHeight)

                divider(horizontalPadding: metrics.horizontalPadding)

                Text(stopwatch.formattedTime)
                    .font(.system(
                        size: metrics.timerFontSize,
                        weight: .heavy,
                        design: .monospaced
                    ))
                    .foregroundColor(.white)
                    .minimumScaleFactor(0.10)
                    .lineLimit(1)
                    .allowsTightening(true)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, metrics.horizontalPadding)

                divider(horizontalPadding: metrics.horizontalPadding)

                informationBlock(
                    label: "SELECTED",
                    title: selectedTitle,
                    metrics: metrics,
                    primary: false
                )
                .frame(height: metrics.informationHeight)

                divider(horizontalPadding: metrics.horizontalPadding)

                statusBar(metrics: metrics)
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
            SettingsView(dismiss: {
                showSettingsSheet = false
            })
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
        metrics: LayoutMetrics,
        primary: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: metrics.labelSpacing) {
            Text(label)
                .font(.system(
                    size: metrics.labelFontSize,
                    weight: .bold,
                    design: .monospaced
                ))
                .foregroundColor(Color.white.opacity(0.48))
                .lineLimit(1)

            Text(title)
                .font(.system(
                    size: primary
                        ? metrics.primaryTitleFontSize
                        : metrics.secondaryTitleFontSize,
                    weight: primary ? .bold : .semibold,
                    design: .default
                ))
                .foregroundColor(primary ? .white : Color.white.opacity(0.90))
                .lineLimit(1)
                .minimumScaleFactor(0.24)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, metrics.horizontalPadding)
        .padding(.vertical, metrics.informationVerticalPadding)
    }

    private func divider(horizontalPadding: CGFloat) -> some View {
        Rectangle()
            .fill(Color.white.opacity(0.16))
            .frame(height: 1)
            .padding(.horizontal, horizontalPadding)
    }

    private func statusBar(metrics: LayoutMetrics) -> some View {
        HStack(spacing: metrics.statusSpacing) {
            StatusLamp(
                label: "MIDI",
                isOn: midi.connectedSourceID != nil,
                color: .green,
                compact: metrics.compact
            )

            StatusLamp(
                label: "SCRIPT",
                isOn: midi.isRemoteScriptActive,
                color: Color(red: 0.0, green: 0.75, blue: 0.90),
                compact: metrics.compact
            )

            StatusLamp(
                label: "CLOCK",
                isOn: midi.isReceivingClock,
                color: .green,
                compact: metrics.compact
            )

            StatusLamp(
                label: "PLAY",
                isOn: stopwatch.isRunning,
                color: .green,
                compact: metrics.compact
            )

            StatusLamp(
                label: "STOP",
                isOn: !stopwatch.isRunning,
                color: .red,
                compact: metrics.compact
            )

            Spacer(minLength: 3)

            Button(action: {
                showSettingsSheet = true
            }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(
                        size: metrics.gearFontSize,
                        weight: .semibold
                    ))
                    .foregroundColor(Color.gray.opacity(0.78))
                    .frame(
                        width: metrics.gearHitSize,
                        height: metrics.gearHitSize
                    )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, metrics.statusHorizontalPadding)
        .frame(height: metrics.statusBarHeight)
    }

    private var currentTitle: String {
        guard let number = midi.currentSceneNumber else {
            return midi.currentSceneName
        }

        return String(format: "%02d   %@", number, midi.currentSceneName)
    }

    private var selectedTitle: String {
        guard let number = midi.selectedSceneNumber else {
            return midi.selectedItemName
        }

        return String(format: "%02d   %@", number, midi.selectedItemName)
    }

    private func updateWindow(_ window: NSWindow) {
        window.level = alwaysOnTop ? .floating : .normal
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.styleMask.insert(.resizable)
        window.minSize = NSSize(width: 450, height: 280)

        guard !didConfigureWindow else { return }
        didConfigureWindow = true
        MainWindowFrameStore.shared.attach(to: window)
    }

    private func updateCurrentWindow() {
        guard let window = NSApp.keyWindow ?? NSApp.windows.first else {
            return
        }

        updateWindow(window)
    }
}

private struct LayoutMetrics {
    let compact: Bool
    let scale: CGFloat
    let horizontalPadding: CGFloat
    let informationVerticalPadding: CGFloat
    let informationHeight: CGFloat
    let labelSpacing: CGFloat
    let labelFontSize: CGFloat
    let primaryTitleFontSize: CGFloat
    let secondaryTitleFontSize: CGFloat
    let timerFontSize: CGFloat
    let statusSpacing: CGFloat
    let statusHorizontalPadding: CGFloat
    let statusBarHeight: CGFloat
    let gearFontSize: CGFloat
    let gearHitSize: CGFloat

    init(size: CGSize) {
        compact = size.width < 650 || size.height < 400

        let widthScale = size.width / 900.0
        let heightScale = size.height / 560.0
        scale = min(max(min(widthScale, heightScale), 0.72), 2.55)

        horizontalPadding = min(max(18.0 * scale, 12.0), 52.0)
        informationVerticalPadding = min(max(10.0 * scale, 6.0), 26.0)
        informationHeight = min(
            max(size.height * (compact ? 0.205 : 0.215), compact ? 56.0 : 78.0),
            250.0
        )
        labelSpacing = min(max(6.0 * scale, 3.0), 15.0)
        labelFontSize = min(max(12.0 * scale, 8.0), 30.0)
        primaryTitleFontSize = min(max(30.0 * scale, 17.0), 78.0)
        secondaryTitleFontSize = min(max(24.0 * scale, 14.0), 64.0)

        let widthBasedTimer = size.width * 0.205
        let heightBasedTimer = size.height * (compact ? 0.31 : 0.34)
        timerFontSize = min(max(min(widthBasedTimer, heightBasedTimer), 54.0), 430.0)

        statusSpacing = compact ? 9.0 : min(max(22.0 * scale, 18.0), 42.0)
        statusHorizontalPadding = compact ? 10.0 : horizontalPadding
        statusBarHeight = compact ? 38.0 : min(max(62.0 * scale, 58.0), 92.0)
        gearFontSize = compact ? 14.0 : min(max(19.0 * scale, 18.0), 31.0)
        gearHitSize = compact ? 25.0 : min(max(34.0 * scale, 34.0), 52.0)
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
