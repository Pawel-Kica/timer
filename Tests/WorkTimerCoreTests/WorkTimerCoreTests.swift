import XCTest
@testable import WorkTimerCore

private let warsaw: Calendar = {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
    return calendar
}()

/// A time on 2026-10-01 in Warsaw.
private func at(_ hour: Int, _ minute: Int = 0) -> Date {
    warsaw.date(from: DateComponents(year: 2026, month: 10, day: 1, hour: hour, minute: minute))!
}

final class StopwatchTests: XCTestCase {
    func testCountsOnlyWhileRunning() {
        var stopwatch = Stopwatch()
        XCTAssertEqual(stopwatch.elapsed(at: at(9)), 0)

        stopwatch.toggle(at: at(9))
        XCTAssertTrue(stopwatch.running)
        XCTAssertEqual(stopwatch.elapsed(at: at(10)), 3600)

        stopwatch.toggle(at: at(10))
        XCTAssertFalse(stopwatch.running)
        XCTAssertEqual(stopwatch.elapsed(at: at(12)), 3600)

        stopwatch.toggle(at: at(12))
        XCTAssertEqual(stopwatch.elapsed(at: at(12, 30)), 5400)
    }

    func testEndReturnsTheSessionAndResets() {
        var stopwatch = Stopwatch()
        stopwatch.toggle(at: at(9))
        stopwatch.toggle(at: at(10))
        stopwatch.toggle(at: at(11))

        XCTAssertEqual(stopwatch.end(at: at(12)), Session(start: at(9), end: at(12), duration: 7200))
        XCTAssertEqual(stopwatch, Stopwatch())
    }

    func testEndWhileIdleLogsNothing() {
        var stopwatch = Stopwatch()
        XCTAssertNil(stopwatch.end(at: at(9)))
    }

    func testSurvivesEncoding() throws {
        var stopwatch = Stopwatch()
        stopwatch.toggle(at: at(9))
        let copy = try JSONDecoder().decode(Stopwatch.self, from: JSONEncoder().encode(stopwatch))
        XCTAssertEqual(copy.elapsed(at: at(10)), 3600)
    }

    func testReminderIsDueOnlyWhenRunningThroughIt() {
        var stopwatch = Stopwatch()
        XCTAssertFalse(stopwatch.reminderDue(minutes: 17 * 60, at: at(18), calendar: warsaw))

        stopwatch.toggle(at: at(9))
        XCTAssertFalse(stopwatch.reminderDue(minutes: 17 * 60, at: at(16, 59), calendar: warsaw))
        XCTAssertTrue(stopwatch.reminderDue(minutes: 17 * 60, at: at(17), calendar: warsaw))

        var late = Stopwatch()
        late.toggle(at: at(18))
        XCTAssertFalse(late.reminderDue(minutes: 17 * 60, at: at(19), calendar: warsaw))
    }
}

final class LogTests: XCTestCase {
    func testClock() {
        XCTAssertEqual(clock(0), "0:00:00")
        XCTAssertEqual(clock(3725.9), "1:02:05")
        XCTAssertEqual(seconds(fromClock: "1:02:05"), 3725)
        XCTAssertNil(seconds(fromClock: "duration"))
        XCTAssertEqual(hoursAndMinutes(8100), "2h 15m")
    }

    func testLine() {
        let session = Session(start: at(8, 5), end: at(10, 20), duration: 8100)
        XCTAssertEqual(Log.line(session, calendar: warsaw), "2026-10-01,08:05,10:20,2:15:00")
    }

    func testTotalCountsOneDay() {
        let text = """
        date,start,end,duration
        2026-09-30,09:00,17:00,8:00:00
        2026-10-01,08:05,10:20,2:15:00
        2026-10-01,11:00,11:30,0:30:00

        """
        XCTAssertEqual(Log.total(on: "2026-10-01", in: text), 9900)
        XCTAssertEqual(Log.total(on: "2026-10-02", in: text), 0)
    }
}
