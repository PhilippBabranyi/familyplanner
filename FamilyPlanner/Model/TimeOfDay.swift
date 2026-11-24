import Foundation

/// A wall-clock time without a date, e.g. 16:20.
struct TimeOfDay: Hashable, Comparable, CustomStringConvertible {
    let hour: Int
    let minute: Int

    /// Returns nil if the values are not a valid time of day.
    init?(hour: Int, minute: Int) {
        guard (0..<24).contains(hour), (0..<60).contains(minute) else { return nil }
        self.hour = hour
        self.minute = minute
    }

    /// Convenience for fixed, known-good values (demo data, tests).
    static func at(_ hour: Int, _ minute: Int) -> TimeOfDay {
        guard let time = TimeOfDay(hour: hour, minute: minute) else {
            preconditionFailure("Invalid time \(hour):\(minute)")
        }
        return time
    }

    var description: String {
        String(format: "%02d:%02d", hour, minute)
    }

    static func < (lhs: TimeOfDay, rhs: TimeOfDay) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }
}
