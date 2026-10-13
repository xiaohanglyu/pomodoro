import XCTest
@testable import PomodoroCore
final class TimerStateTests: XCTestCase {
    let t = Date(timeIntervalSince1970: 10000)
    func testExistingScenarios() throws {
        var s = TimerState(); s.taskTitle = "LeetCode"; s.calendarID = "test"
        s.start(at:t); s.pause(at:t.addingTimeInterval(60))
        XCTAssertEqual(s.remaining, 1440); XCTAssertEqual(s.logs.count, 1)
        s.start(at:t.addingTimeInterval(360)); s.pause(at:t.addingTimeInterval(420))
        XCTAssertEqual(s.remaining, 1380)
        XCTAssertEqual(s.logs.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) }, 120)
        var a = TimerState(); a.start(at:t)
        a.finish(at:t.addingTimeInterval(1503), autoStartBreak:true)
        XCTAssertEqual(a.phase, .shortBreak); XCTAssertEqual(a.logs[0].end, t.addingTimeInterval(1500))
        XCTAssertEqual(a.segmentStart, t.addingTimeInterval(1503))
        a.finish(at:t.addingTimeInterval(1803), autoStartBreak:false)
        XCTAssertEqual(a.phase, .focus); XCTAssertNil(a.deadline)
        var b = TimerState(); b.completedFocus = 3; b.start(at:t)
        b.finish(at:t.addingTimeInterval(1500), autoStartBreak:false)
        XCTAssertEqual(b.phase, .longBreak); XCTAssertEqual(b.remaining, 900)
        var c = TimerState(); c.start(at:t); c.endEarly(at:t.addingTimeInterval(35))
        XCTAssertEqual(c.completedFocus, 0); XCTAssertEqual(c.logs.count, 1); XCTAssertEqual(c.remaining, 1500)
        let recovered = try JSONDecoder().decode(TimerState.self, from: JSONEncoder().encode(a))
        XCTAssertEqual(recovered.logs.count, 1); XCTAssertEqual(recovered.completedFocus, 1)
    }
    func testPrematureFinishAndRepeatedStart() {
        var s = TimerState(); s.start(at:t); s.start(at:t.addingTimeInterval(50))
        s.finish(at:t.addingTimeInterval(60), autoStartBreak:true)
        XCTAssertEqual(s.deadline, t.addingTimeInterval(1500)); XCTAssertEqual(s.completedFocus, 0)
    }
    func testExpiredPauseFinishesOnce() {
        var s = TimerState(); s.start(at:t); s.pause(at:t.addingTimeInterval(1600))
        s.pause(at:t.addingTimeInterval(1700))
        XCTAssertEqual(s.completedFocus, 1); XCTAssertEqual(s.logs.count, 1)
        XCTAssertEqual(s.logs[0].end, t.addingTimeInterval(1500))
    }
    func testSegmentKeepsOriginalMetadataAcrossPersistence() throws {
        var s = TimerState(); s.taskTitle = "Original"; s.calendarID = "A"; s.start(at:t)
        s = try JSONDecoder().decode(TimerState.self, from: JSONEncoder().encode(s))
        s.taskTitle = "Changed"; s.calendarID = "B"; s.pause(at:t.addingTimeInterval(30))
        XCTAssertEqual(s.logs[0].title, "Original"); XCTAssertEqual(s.logs[0].calendarID, "A")
    }
}
