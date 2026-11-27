// What the screens need to know about a pickup, besides the weekly schedule.

/// A pickup that nobody has taken over yet, for the bell.
struct OpenPickup: Identifiable, Equatable {
    /// `yyyy-MM-dd`
    let dayText: String
    let time: TimeOfDay
    let isToday: Bool
    /// The child whose pickup is open, nil if no child is set up.
    var child: PickupChild?

    var id: String { "\(child?.id ?? "")-\(dayText)" }
    var label: String { child?.label ?? "Pickup" }
}

/// The pickup shown on the today screen.
struct TodayPickup: Equatable, Identifiable {
    /// "Pickup Kim"
    let label: String
    let time: TimeOfDay
    let driver: String?
    let mark: PickupMark

    var id: String { label }
}
