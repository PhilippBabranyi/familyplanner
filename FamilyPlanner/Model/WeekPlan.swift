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

/// How a day's pickup is marked: red when nobody is entered, orange when it differs from the weekly plan,
/// otherwise in the colour of the person who picks up.
enum PickupMark: Equatable {
    case open
    case changed
    case assigned
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
    /// What to take along, by weekday of this week.
    var bringByDay: [Weekday: String] = [:]
    /// Days of this week whose note was set for that single day.
    var bringChangedDays: Set<Weekday> = []

    /// The mark of a day's pickup, nil if there is no pickup (and no change) on that day.
    func pickupMark(on day: Weekday) -> PickupMark? {
        if overrideByDay[day] == .cancelled { return .changed }
        guard pickupTime(on: day) != nil else { return nil }
        if driverByDay[day] == nil { return .open }
        return overrideByDay[day] == nil ? .assigned : .changed
    }

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
