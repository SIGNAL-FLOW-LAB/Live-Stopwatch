import Foundation
import Combine
import CoreMIDI
import Network

/// Handles both:
/// - MIDI Start / Stop / Continue / Clock from IAC Driver
/// - Local UDP messages from the Ableton Remote Script
final class MIDIController: ObservableObject {
    @Published private(set) var sources: [MIDISourceItem] = []
    @Published var selectedSourceID: MIDIEndpointRef?

    @Published private(set) var connectedSourceID: MIDIEndpointRef?
    @Published private(set) var connectionMessage = "MIDI未接続"
    @Published private(set) var isReceivingClock = false
    @Published private(set) var isRemoteScriptActive = false
    @Published private(set) var remoteScriptVersion = "未接続"
    @Published private(set) var lastMIDIStartDate: Date?
    @Published private(set) var lastMIDIStopDate: Date?
    @Published private(set) var lastRemoteMessageDate: Date?

    @Published private(set) var currentSceneNumber: Int?
    @Published private(set) var currentSceneName = "曲情報待ち"
    @Published private(set) var selectedSceneNumber: Int?
    @Published private(set) var selectedItemName = "—"

    @Published private(set) var eventLog: [EventLogItem] = []

    weak var stopwatch: StopwatchModel?

    private var client = MIDIClientRef()
    private var inputPort = MIDIPortRef()
    private var connectedEndpoint = MIDIEndpointRef()

    private var lastClockDate: Date?
    private var lastRemoteScriptDate: Date?
    private var monitorTimer: Timer?

    private var udpListener: NWListener?
    private let udpPort: NWEndpoint.Port = 45_722

    private let selectedSourceNameKey = "SelectedMIDISourceName"
    private var hasStarted = false

    func start() {
        guard !hasStarted else {
            return
        }

        hasStarted = true

        createMIDIClient()
        createMIDIInputPort()
        refreshSources()
        restoreOrAutoConnect()
        startStatusMonitor()
        startRemoteScriptListener()
    }

    func shutdown() {
        guard hasStarted else {
            return
        }

        hasStarted = false
        disconnect()

        monitorTimer?.invalidate()
        monitorTimer = nil

        udpListener?.cancel()
        udpListener = nil

        if inputPort != 0 {
            MIDIPortDispose(inputPort)
            inputPort = 0
        }

        if client != 0 {
            MIDIClientDispose(client)
            client = 0
        }
    }

    // MARK: - CoreMIDI

    private func createMIDIClient() {
        guard client == 0 else { return }

        let status = MIDIClientCreate(
            "Ableton Live Stopwatch by SIGNAL FLOW" as CFString,
            midiNotificationCallback,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &client
        )

        if status != noErr {
            connectionMessage = "CoreMIDI初期化失敗: \(status)"
        }
    }

    private func createMIDIInputPort() {
        guard client != 0, inputPort == 0 else { return }

        let status = MIDIInputPortCreate(
            client,
            "SIGNAL FLOW Stopwatch MIDI Input" as CFString,
            midiReadCallback,
            UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque()),
            &inputPort
        )

        if status != noErr {
            connectionMessage = "MIDI入力作成失敗: \(status)"
        }
    }

    func refreshSources() {
        var result: [MIDISourceItem] = []

        for index in 0..<MIDIGetNumberOfSources() {
            let source = MIDIGetSource(index)
            guard source != 0 else { continue }

            result.append(
                MIDISourceItem(
                    id: source,
                    name: displayName(for: source)
                )
            )
        }

        sources = result.sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    func connectSelected() {
        guard let selectedSourceID = selectedSourceID else {
            connectionMessage = "MIDI入力を選択してください"
            return
        }

        connect(to: selectedSourceID)
    }

    func connect(to endpoint: MIDIEndpointRef) {
        guard inputPort != 0 else {
            connectionMessage = "MIDI入力が未初期化です"
            return
        }

        if connectedEndpoint != 0 {
            MIDIPortDisconnectSource(inputPort, connectedEndpoint)
        }

        let status = MIDIPortConnectSource(inputPort, endpoint, nil)

        guard status == noErr else {
            connectedEndpoint = 0
            connectedSourceID = nil
            connectionMessage = "接続失敗: \(status)"
            return
        }

        connectedEndpoint = endpoint
        connectedSourceID = endpoint
        selectedSourceID = endpoint

        let name = displayName(for: endpoint)
        UserDefaults.standard.set(name, forKey: selectedSourceNameKey)
        connectionMessage = "接続中: \(name)"
        appendLog("MIDI CONNECTED: \(name)")
    }

    func disconnect() {
        if connectedEndpoint != 0 && inputPort != 0 {
            MIDIPortDisconnectSource(inputPort, connectedEndpoint)
        }

        connectedEndpoint = 0
        connectedSourceID = nil
        isReceivingClock = false
        lastClockDate = nil
        connectionMessage = "MIDI未接続"
    }

    private func restoreOrAutoConnect() {
        let savedName = UserDefaults.standard.string(
            forKey: selectedSourceNameKey
        )

        let savedSource = savedName.flatMap { savedName in
            sources.first { $0.name == savedName }
        }

        let iacSource = sources.first {
            $0.name.localizedCaseInsensitiveContains("IAC")
                || $0.name.localizedCaseInsensitiveContains("Bus 1")
                || $0.name.localizedCaseInsensitiveContains("バス1")
        }

        if let source = savedSource ?? iacSource {
            selectedSourceID = source.id
            connect(to: source.id)
        }
    }

    private func displayName(for endpoint: MIDIEndpointRef) -> String {
        var value: Unmanaged<CFString>?

        if MIDIObjectGetStringProperty(
            endpoint,
            kMIDIPropertyDisplayName,
            &value
        ) == noErr, let name = value?.takeRetainedValue() {
            return name as String
        }

        if MIDIObjectGetStringProperty(
            endpoint,
            kMIDIPropertyName,
            &value
        ) == noErr, let name = value?.takeRetainedValue() {
            return name as String
        }

        return "MIDI Source \(endpoint)"
    }

    fileprivate func handle(packetList: UnsafePointer<MIDIPacketList>) {
        var packet = packetList.pointee.packet

        for _ in 0..<packetList.pointee.numPackets {
            let length = Int(packet.length)

            withUnsafePointer(to: &packet.data) { dataPointer in
                dataPointer.withMemoryRebound(
                    to: UInt8.self,
                    capacity: length
                ) { bytes in
                    var index = 0

                    while index < length {
                        let status = bytes[index]

                        switch status {
                        case 0xF8:
                            DispatchQueue.main.async {
                                self.lastClockDate = Date()
                                if !self.isReceivingClock {
                                    self.isReceivingClock = true
                                }
                            }
                            index += 1

                        case 0xFA:
                            DispatchQueue.main.async {
                                self.lastMIDIStartDate = Date()
                                self.appendLog("MIDI START")
                                self.stopwatch?.handleMIDIStart()
                            }
                            index += 1

                        case 0xFB:
                            DispatchQueue.main.async {
                                self.appendLog("MIDI CONTINUE")
                                self.stopwatch?.handleMIDIContinue()
                            }
                            index += 1

                        case 0xFC:
                            DispatchQueue.main.async {
                                self.lastMIDIStopDate = Date()
                                self.appendLog("MIDI STOP")
                                self.stopwatch?.handleMIDIStop()
                            }
                            index += 1

                        default:
                            index += self.midiMessageLength(for: status)
                        }
                    }
                }
            }

            packet = MIDIPacketNext(&packet).pointee
        }
    }

    private func midiMessageLength(for status: UInt8) -> Int {
        if status < 0x80 {
            return 1
        }

        switch status & 0xF0 {
        case 0xC0, 0xD0:
            return 2
        case 0x80, 0x90, 0xA0, 0xB0, 0xE0:
            return 3
        default:
            return 1
        }
    }

    // MARK: - UDP Remote Script

    private func startRemoteScriptListener() {
        do {
            let parameters = NWParameters.udp
            parameters.allowLocalEndpointReuse = true

            let listener = try NWListener(
                using: parameters,
                on: udpPort
            )

            listener.stateUpdateHandler = { [weak self] state in
                DispatchQueue.main.async {
                    switch state {
                    case .ready:
                        self?.appendLog("REMOTE SCRIPT LISTENER READY")
                    case .failed(let error):
                        self?.appendLog(
                            "REMOTE SCRIPT ERROR: \(error.localizedDescription)"
                        )
                    default:
                        break
                    }
                }
            }

            listener.newConnectionHandler = { [weak self] connection in
                connection.start(queue: .global(qos: .userInitiated))
                self?.receiveMessage(on: connection)
            }

            listener.start(queue: .global(qos: .userInitiated))
            udpListener = listener

        } catch {
            appendLog("REMOTE SCRIPT LISTENER FAILED")
        }
    }

    private func receiveMessage(on connection: NWConnection) {
        connection.receiveMessage { [weak self] data, _, _, _ in
            guard let data = data, !data.isEmpty else {
                connection.cancel()
                return
            }

            DispatchQueue.main.async {
                self?.handleRemoteScriptMessage(data)
            }

            connection.cancel()
        }
    }

    private func handleRemoteScriptMessage(_ data: Data) {
        guard
            let json = try? JSONSerialization.jsonObject(
                with: data,
                options: []
            ),
            let object = json as? [String: Any],
            let type = object["type"] as? String
        else {
            appendLog("INVALID REMOTE SCRIPT MESSAGE")
            return
        }

        lastRemoteScriptDate = Date()
        lastRemoteMessageDate = lastRemoteScriptDate
        isRemoteScriptActive = true

        switch type {
        case "hello":
            let version = object["version"] as? String ?? "不明"
            remoteScriptVersion = version
            appendLog("REMOTE SCRIPT CONNECTED v\(version)")

        case "scene_change":
            let index = object["scene_index"] as? Int ?? -1
            let name = object["scene_name"] as? String ?? "名称未設定"

            currentSceneNumber = index >= 0 ? index + 1 : nil
            currentSceneName = name

            stopwatch?.resetAndStart()
            appendLog("SCENE \(index + 1): \(name)")

        case "selected_item":
            let index = object["scene_index"] as? Int ?? -1
            let name = object["display_name"] as? String ?? "—"

            selectedSceneNumber = index >= 0 ? index + 1 : nil
            selectedItemName = name

        case "scene_stop":
            appendLog("SCENE STOP")
            stopwatch?.handleMIDIStop()

        case "transport_stop":
            appendLog("TRANSPORT STOP")
            stopwatch?.handleMIDIStop()

        case "transport_start":
            appendLog("TRANSPORT START")

        default:
            appendLog("REMOTE SCRIPT: \(type)")
        }
    }

    // MARK: - Status / Log

    private func startStatusMonitor() {
        monitorTimer = Timer.scheduledTimer(
            withTimeInterval: 1.0,
            repeats: true
        ) { [weak self] _ in
            guard let self = self else { return }

            let clockActive: Bool
            if let date = self.lastClockDate {
                clockActive = Date().timeIntervalSince(date) < 1.5
            } else {
                clockActive = false
            }

            if self.isReceivingClock != clockActive {
                self.isReceivingClock = clockActive
            }

            let scriptActive: Bool
            if let date = self.lastRemoteScriptDate {
                scriptActive = Date().timeIntervalSince(date) < 6.0
            } else {
                scriptActive = false
            }

            if self.isRemoteScriptActive != scriptActive {
                self.isRemoteScriptActive = scriptActive
            }
        }

        if let timer = monitorTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    func appendLog(_ message: String) {
        eventLog.append(
            EventLogItem(
                date: Date(),
                message: message
            )
        )

        if eventLog.count > 50 {
            eventLog.removeFirst(eventLog.count - 50)
        }
    }
}

private let midiNotificationCallback: MIDINotifyProc = {
    _, refCon in

    guard let refCon = refCon else { return }

    let controller = Unmanaged<MIDIController>
        .fromOpaque(refCon)
        .takeUnretainedValue()

    DispatchQueue.main.async {
        controller.refreshSources()
    }
}

private let midiReadCallback: MIDIReadProc = {
    packetList, refCon, _ in

    guard let refCon = refCon else { return }

    let controller = Unmanaged<MIDIController>
        .fromOpaque(refCon)
        .takeUnretainedValue()

    controller.handle(packetList: packetList)
}
