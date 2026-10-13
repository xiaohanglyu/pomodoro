import Foundation

public struct ActivityEntry: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let message: String
    public init(_ message: String, at date: Date = Date()) {
        self.id = UUID(); self.date = date; self.message = message
    }
}

public struct CalendarSyncState: Codable {
    public private(set) var pending: Set<UUID> = []
    public private(set) var synced: Set<UUID> = []
    public init() {}
    public mutating func enqueue(_ records: [FocusLog]) {
        for record in records where !synced.contains(record.id) { pending.insert(record.id) }
    }
    public mutating func markSynced(_ id: UUID) {
        pending.remove(id); synced.insert(id)
    }
}
