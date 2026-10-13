import Foundation
import PomodoroCore
@main struct Tests {
 static func main() throws {
 let t = Date(timeIntervalSince1970: 10000)
 var s = TimerState(); s.taskTitle = "LeetCode"; s.calendarID = "test"
 s.start(at:t); s.pause(at:t.addingTimeInterval(60))
 assert(s.remaining == 1440 && s.logs.count == 1)
 s.start(at:t.addingTimeInterval(360)); s.pause(at:t.addingTimeInterval(420))
 assert(s.remaining == 1380 && s.logs.count == 2)
 assert(s.logs.reduce(0) { $0 + $1.end.timeIntervalSince($1.start) } == 120)
 var a = TimerState(); a.taskTitle = "Task"; a.start(at:t)
 a.finish(at:t.addingTimeInterval(1503),autoStartBreak:true)
 assert(a.phase == .shortBreak && a.completedFocus == 1)
 assert(a.logs[0].end == t.addingTimeInterval(1500))
 assert(a.segmentStart == t.addingTimeInterval(1503))
 a.finish(at:t.addingTimeInterval(1803),autoStartBreak:false)
 assert(a.phase == .focus && a.deadline == nil)
 var b = TimerState(); b.completedFocus=3; b.start(at:t); b.finish(at:t.addingTimeInterval(1500),autoStartBreak:false)
 assert(b.phase == .longBreak && b.remaining == 900)
 var c = TimerState(); c.start(at:t); c.endEarly(at:t.addingTimeInterval(35))
 assert(c.completedFocus == 0 && c.logs.count == 1 && c.remaining == 1500)
 let recovered = try JSONDecoder().decode(TimerState.self,from:JSONEncoder().encode(a))
 assert(recovered.logs.count == 1 && recovered.completedFocus == 1)
 print("PASS: pause/resume, excluded gaps, deadline clipping, automatic break, manual next focus, fourth-session long break, early end, persistence")
 }
}
