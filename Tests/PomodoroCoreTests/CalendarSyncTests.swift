import XCTest
@testable import PomodoroCore
final class CalendarSyncTests: XCTestCase {
    func testPendingSyncSurvivesRestartAndSuccessfulRetry() throws {
        var timer = TimerState()
        let date = Date(timeIntervalSince1970: 1000)
        timer.start(at: date); timer.pause(at: date.addingTimeInterval(20))
        var sync = CalendarSyncState()
        sync.enqueue(timer.logs)
        sync = try JSONDecoder().decode(CalendarSyncState.self, from: JSONEncoder().encode(sync))
        let id = try XCTUnwrap(timer.logs.first?.id)
        XCTAssertTrue(sync.pending.contains(id))
        sync.markSynced(id)
        sync.enqueue(timer.logs)
        XCTAssertTrue(sync.pending.isEmpty)
        XCTAssertEqual(sync.synced, [id])
    }
    func testPauseAndStopQueueSeparateSegmentsWithoutPauseTime() {
        let date = Date(timeIntervalSince1970: 1000)
        var timer = TimerState(); var sync = CalendarSyncState()
        timer.start(at: date); timer.pause(at: date.addingTimeInterval(20))
        sync.enqueue(timer.logs)
        timer.start(at: date.addingTimeInterval(100)); timer.endEarly(at: date.addingTimeInterval(130))
        sync.enqueue(timer.logs)
        XCTAssertEqual(sync.pending.count, 2)
        XCTAssertEqual(timer.logs.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }, 50)
    }
    func testActivityRetainsTimestampAndMessage() throws {
        let entry = ActivityEntry("Paused Focus.", at: Date(timeIntervalSince1970: 1000))
        let saved = try JSONDecoder().decode(ActivityEntry.self, from: JSONEncoder().encode(entry))
        XCTAssertEqual(saved.id, entry.id); XCTAssertEqual(saved.date, entry.date)
        XCTAssertEqual(saved.message, "Paused Focus.")
    }
}
