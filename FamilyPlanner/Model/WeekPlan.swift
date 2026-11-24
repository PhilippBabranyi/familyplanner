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
}

/// All items of one week plus the pickup schedule.
struct WeekPlan {
    var pickup: PickupSchedule
    var itemsByDay: [Weekday: [WeekItem]]

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
