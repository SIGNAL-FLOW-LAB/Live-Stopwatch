import Foundation
import CoreMIDI

struct MIDISourceItem: Identifiable, Hashable {
    let id: MIDIEndpointRef
    let name: String
}

struct EventLogItem: Identifiable {
    let id = UUID()
    let date: Date
    let message: String
}
