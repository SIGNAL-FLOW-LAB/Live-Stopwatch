import Foundation
import Combine

/// Low-overhead stopwatch for live operation.
///
/// The UI is refreshed 10 times per second because the display shows tenths.
/// This avoids the 50 Hz redraw load used by the prototype versions.
final class StopwatchModel: ObservableObject {
    @Published private(set) var elapsed: TimeInterval = 0
    @Published private(set) var isRunning = false

    @Published var resetOnMIDIStop: Bool {
        didSet {
            UserDefaults.standard.set(
                resetOnMIDIStop,
                forKey: "ResetOnMIDIStop"
            )
        }
    }

    private var accumulated: TimeInterval = 0
    private var startedAtUptime: TimeInterval?
    private var timer: DispatchSourceTimer?

    init() {
        if UserDefaults.standard.object(
            forKey: "ResetOnMIDIStop"
        ) == nil {
            resetOnMIDIStop = true
        } else {
            resetOnMIDIStop = UserDefaults.standard.bool(
                forKey: "ResetOnMIDIStop"
            )
        }

        startDisplayTimer()
    }

    deinit {
        timer?.cancel()
    }

    func handleMIDIStart() {
        // MIDI START is the beginning of a new playback run.
        // Reset is intentionally part of the app's fixed behavior.
        resetAndStart()
    }

    func handleMIDIContinue() {
        start()
    }

    func handleMIDIStop() {
        if resetOnMIDIStop {
            reset()
        } else {
            pause()
        }
    }

    func resetAndStart() {
        accumulated = 0
        elapsed = 0
        startedAtUptime = ProcessInfo.processInfo.systemUptime
        if !isRunning {
            isRunning = true
        }
    }

    func start() {
        guard !isRunning else { return }
        startedAtUptime = ProcessInfo.processInfo.systemUptime
        isRunning = true
    }

    func pause() {
        guard isRunning, let started = startedAtUptime else { return }

        accumulated += ProcessInfo.processInfo.systemUptime - started
        startedAtUptime = nil
        isRunning = false
        publishElapsed(accumulated)
    }

    func reset() {
        accumulated = 0
        startedAtUptime = nil
        isRunning = false
        publishElapsed(0)
    }

    private func startDisplayTimer() {
        let source = DispatchSource.makeTimerSource(
            queue: DispatchQueue.main
        )
        source.schedule(
            deadline: .now() + 0.1,
            repeating: 0.1,
            leeway: .milliseconds(15)
        )
        source.setEventHandler { [weak self] in
            self?.refreshDisplay()
        }
        source.resume()
        timer = source
    }

    private func refreshDisplay() {
        guard isRunning, let started = startedAtUptime else { return }

        let value = accumulated
            + (ProcessInfo.processInfo.systemUptime - started)

        publishElapsed(value)
    }

    private func publishElapsed(_ value: TimeInterval) {
        // Publish only when the displayed tenth changes.
        let oldTenths = Int(elapsed * 10)
        let newTenths = Int(value * 10)

        if oldTenths != newTenths || value == 0 {
            elapsed = value
        }
    }

    var formattedTime: String {
        let totalTenths = max(0, Int(elapsed * 10))
        let hours = totalTenths / 36_000
        let minutes = (totalTenths / 600) % 60
        let seconds = (totalTenths / 10) % 60
        let tenths = totalTenths % 10

        if hours > 0 {
            return String(
                format: "%02d:%02d:%02d.%01d",
                hours,
                minutes,
                seconds,
                tenths
            )
        }

        return String(
            format: "%02d:%02d.%01d",
            minutes,
            seconds,
            tenths
        )
    }
}
