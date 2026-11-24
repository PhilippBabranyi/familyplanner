/// People shown in the app. Real names live in the backend, never in this repository.
enum Person: String, CaseIterable {
    case alex
    case sam
    case helper
    case everyone

    var initial: String {
        switch self {
        case .alex: return "A"
        case .sam: return "S"
        case .helper: return "H"
        case .everyone: return "F"
        }
    }
}

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
    var owner: Person = .everyone
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
