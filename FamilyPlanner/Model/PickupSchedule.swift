/// When the kids are picked up, with per-weekday exceptions.
///
/// Example: pickup is 15:20 on school days, but 16:20 on Thursdays (ballet).
struct PickupSchedule {
    /// Days on which there is a pickup at all.
    var pickupDays: Set<Weekday>
    var defaultTime: TimeOfDay
    var exceptions: [Weekday: TimeOfDay]

    /// The pickup time on the given day, or nil if there is no pickup that day.
    func time(on day: Weekday) -> TimeOfDay? {
        guard pickupDays.contains(day) else { return nil }
        return exceptions[day] ?? defaultTime
    }

    /// True if the day has a pickup time that differs from the default.
    func isException(on day: Weekday) -> Bool {
        guard let time = time(on: day) else { return false }
        return time != defaultTime
    }
}
