import Foundation

public enum Phase: String, Codable { case focus, shortBreak, longBreak
    public var duration: TimeInterval { switch self { case .focus: return 1500; case .shortBreak: return 300; case .longBreak: return 900 } }
    public var title: String { switch self { case .focus: return "Focus"; case .shortBreak: return "Short Break"; case .longBreak: return "Long Break" } }
}
public struct FocusLog: Codable, Identifiable {
    public var id = UUID()
    public let start: Date
    public let end: Date
    public let title: String
    public let calendarID: String?
}
public struct TimerState: Codable {
    public var phase: Phase = .focus
    public var remaining: TimeInterval = 1500
    public var completedFocus = 0
    public var taskTitle = ""
    public var calendarID: String?
    public var deadline: Date?
    public var segmentStart: Date?
    public var logs: [FocusLog] = []
    private var segmentTitle: String?
    private var segmentCalendarID: String?
    public init() {}
    public func seconds(at date: Date) -> TimeInterval { max(0, deadline.map { $0.timeIntervalSince(date) } ?? remaining) }
    public mutating func start(at date: Date) {
        guard deadline == nil else { return }
        deadline = date.addingTimeInterval(remaining)
        segmentStart = date
        segmentTitle = taskTitle
        segmentCalendarID = calendarID
    }
    private mutating func close(at date: Date) {
        if phase == .focus, let start = segmentStart {
            let end = min(date, deadline ?? date)
            if end > start { logs.append(FocusLog(start: start, end: end, title: segmentTitle ?? taskTitle, calendarID: segmentCalendarID)) }
        }
        segmentStart = nil
        segmentTitle = nil
        segmentCalendarID = nil
    }
    public mutating func pause(at date: Date) {
        guard deadline != nil else { return }
        if seconds(at: date) == 0 { finish(at: date, autoStartBreak: false); return }
        remaining = seconds(at: date)
        close(at: date)
        deadline = nil
    }
    public mutating func finish(at date: Date, autoStartBreak: Bool) {
        guard let deadline, date >= deadline else { return }
        close(at: deadline)
        if phase == .focus { completedFocus += 1; phase = completedFocus % 4 == 0 ? .longBreak : .shortBreak }
        else { phase = .focus }
        self.deadline = nil
        remaining = phase.duration
        if autoStartBreak && phase != .focus { start(at: date) }
    }
    public mutating func endEarly(at date: Date) {
        if let deadline, date >= deadline { finish(at: date, autoStartBreak: false); return }
        close(at: date)
        deadline = nil
        remaining = phase.duration
    }
}
