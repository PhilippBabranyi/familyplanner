/// Optional label on a week item.
enum ItemTag: Equatable {
    case homeAssistant
    /// Cash needed for this item, in cents.
    case cash(cents: Int)
}

struct WeekItem: Identifiable {
    let id: String
    let time: TimeOfDay
    let title: String
    var note: String?
    /// Display name of the person the item is for, nil if it is for everyone.
    var assignee: String?
    var tag: ItemTag?
    /// The stored item this entry comes from, nil for demo entries.
    var sourceId: String?
}

/// All items of one week plus the pickup schedule.
struct WeekPlan {
    var pickup: PickupSchedule
    var itemsByDay: [Weekday: [WeekItem]]
    /// Holidays by weekday of this week (value is the holiday name). No pickup on these days.
    var holidays: [Weekday: String] = [:]
    /// Account (member id) that picks up, by weekday of this week. A missing day means nobody is entered yet.
    var driverByDay: [Weekday: String] = [:]
    /// Changes of the pickup on single days of this week.
    var overrideByDay: [Weekday: PickupOverride] = [:]

    /// The pickup time of a day: the change for that day if there is one, otherwise the weekly time.
    func pickupTime(on day: Weekday) -> TimeOfDay? {
        switch overrideByDay[day] {
        case let .time(time)?: return time
        case .cancelled?: return nil
        case nil: return pickup.time(on: day)
        }
    }

    /// Items of a day, earliest first.
    func items(on day: Weekday) -> [WeekItem] {
        (itemsByDay[day] ?? []).sorted { $0.time < $1.time }
    }

    /// Cash needed on a single day, in cents.
    func cashNeededCents(on day: Weekday) -> Int {
        items(on: day).reduce(0) { total, item in
            if case let .cash(cents)? = item.tag { return total + cents }
            return total
        }
    }

    /// Cash needed over the whole week, in cents.
    var cashNeededCents: Int {
        Weekday.allCases.reduce(0) { $0 + cashNeededCents(on: $1) }
    }
}
