import Foundation

/// One ended session, what End writes to the log.
public struct Session: Equatable {
    public let start: Date
    public let end: Date
    public let duration: TimeInterval
}

/// The timer. Time is banked seconds plus the stretch since the last start, both wall clock, so it counts through sleep
/// and survives a relaunch.
public struct Stopwatch: Codable, Equatable {
    public var banked: TimeInterval = 0
    /// Start of the running stretch, nil while stopped.
    public var since: Date?
    /// First start of this session, nil while idle.
    public var began: Date?

    public init() {}

    public var running: Bool { since != nil }

    public func elapsed(at now: Date) -> TimeInterval {
        banked + (since.map { now.timeIntervalSince($0) } ?? 0)
    }

    /// Start, stop or resume.
    public mutating func toggle(at now: Date) {
        if running {
            banked = elapsed(at: now)
            since = nil
        } else {
            since = now
            began = began ?? now
        }
    }

    /// Resets to zero and returns the session to log, nil when nothing was timed.
    public mutating func end(at now: Date) -> Session? {
        let session = began.map { Session(start: $0, end: now, duration: elapsed(at: now)) }
        self = Stopwatch()
        return session
    }

    /// True once the timer has run through today's reminder time, given as minutes since midnight. A timer started
    /// after that time is not due.
    public func reminderDue(minutes: Int, at now: Date, calendar: Calendar = .current) -> Bool {
        guard let since,
              let time = calendar.date(bySettingHour: minutes / 60, minute: minutes % 60, second: 0, of: now)
        else { return false }
        return since <= time && now >= time
    }
}
