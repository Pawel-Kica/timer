import Foundation

/// 3725 -> "1:02:05", what the menu bar and the log show.
public func clock(_ seconds: TimeInterval) -> String {
    let total = Int(seconds)
    return String(format: "%d:%02d:%02d", total / 3600, total / 60 % 60, total % 60)
}

/// "1:02:05" -> 3725, nil when the text isn't a clock.
public func seconds(fromClock text: String) -> TimeInterval? {
    let parts = text.split(separator: ":").compactMap { Int($0) }
    guard parts.count == 3 else { return nil }
    return TimeInterval(parts[0] * 3600 + parts[1] * 60 + parts[2])
}

/// 8100 -> "2h 15m", for the Today line in the menu.
public func hoursAndMinutes(_ seconds: TimeInterval) -> String {
    let minutes = Int(seconds) / 60
    return "\(minutes / 60)h \(minutes % 60)m"
}

/// The log is a CSV with one line per ended session: date,start,end,duration.
public enum Log {
    public static let header = "date,start,end,duration"

    /// "2026-10-01". A session counts for the day it ended on.
    public static func day(_ date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
    }

    public static func line(_ session: Session, calendar: Calendar = .current) -> String {
        let time = { (date: Date) -> String in
            let parts = calendar.dateComponents([.hour, .minute], from: date)
            return String(format: "%02d:%02d", parts.hour!, parts.minute!)
        }
        return [day(session.end, calendar: calendar), time(session.start), time(session.end), clock(session.duration)]
            .joined(separator: ",")
    }

    /// Sum of the durations logged on one day.
    public static func total(on day: String, in text: String) -> TimeInterval {
        text.split(whereSeparator: \.isNewline).reduce(0) { sum, line in
            let fields = line.split(separator: ",")
            guard fields.count == 4, fields[0] == day else { return sum }
            return sum + (seconds(fromClock: String(fields[3])) ?? 0)
        }
    }
}
