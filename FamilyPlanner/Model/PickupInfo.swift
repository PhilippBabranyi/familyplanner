// What the screens need to know about a pickup, besides the weekly schedule.

/// A pickup that nobody has taken over yet, for the bell.
struct OpenPickup: Identifiable, Equatable {
    /// `yyyy-MM-dd`
    let dayText: String
    let time: TimeOfDay
    let isToday: Bool

    var id: String { dayText }
}

/// The pickup shown on the today screen.
struct TodayPickup: Equatable {
    let time: TimeOfDay
    let driver: String?
    let mark: PickupMark
}
