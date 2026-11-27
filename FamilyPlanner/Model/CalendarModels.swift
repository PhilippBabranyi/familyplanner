import Foundation

/// A person who can be picked for a task or an item: a family member with an account, or a person of the
/// household without one (a child). The id of the latter starts with `Member.personPrefix`.
struct Member: Identifiable, Hashable {
    static let personPrefix = "person:"

    let id: String
    let name: String

    /// The database id of a person without an account, nil for family members.
    var personId: String? { Member.personId(from: id) }

    static func personId(from memberId: String?) -> String? {
        guard let memberId, memberId.hasPrefix(personPrefix) else { return nil }
        return String(memberId.dropFirst(personPrefix.count))
    }
}

/// A calendar item as stored in the database, before it is placed in a concrete week.
struct StoredCalendarItem: Identifiable {
    let id: String
    var title: String
    var note: String?
    /// First (or only) day, `yyyy-MM-dd`.
    var startsOn: String
    var time: TimeOfDay
    /// Weekdays of a series. Empty means a one-off item on `startsOn`.
    var weekdays: Set<Weekday> = []
    /// Last day of a series, `yyyy-MM-dd`. Nil means open end.
    var repeatUntil: String?
    /// If true, the series does not occur on holidays.
    var skipHolidays = false
    var assigneeId: String?
    var assignee: String?
    var cashCents: Int?
    /// The mail this item was created from, if any.
    var source: MailSource?

    var isSeries: Bool { !weekdays.isEmpty }
}

struct Holiday: Identifiable, Equatable {
    let id: String
    var name: String
    /// First and last day, `yyyy-MM-dd`.
    var startsOn: String
    var endsOn: String

    func contains(_ dayText: String) -> Bool {
        startsOn <= dayText && dayText <= endsOn
    }
}

/// A pickup that differs on a single day, like one changed occurrence of a series.
enum PickupOverride: Equatable {
    /// The pickup is at this time on that day.
    case time(TimeOfDay)
    /// There is no pickup on that day.
    case cancelled
}

/// Everything the week and today screens are built from.
struct CalendarData {
    var items: [StoredCalendarItem] = []
    var pickups: [Weekday: TimeOfDay] = [:]
    var holidays: [Holiday] = []
    /// Account (member id) that picks up on a day, by `yyyy-MM-dd`. A missing day means nobody is entered yet.
    var pickupDrivers: [String: String] = [:]
    /// Changes of the pickup on single days, by `yyyy-MM-dd`.
    var pickupOverrides: [String: PickupOverride] = [:]
    /// Minutes before the pickup at which the person who picks up gets the reminder.
    var remindMinutes = 30
    /// What to take along, by weekday and start day (the rhythm), and for single days by `yyyy-MM-dd`.
    var pickupNotes: [PickupNote] = []
    var pickupNoteOverrides: [String: String] = [:]
    /// How the family calls the pickup.
    var pickupLabel = "Pickup"
}

/// Input of the task form. A nil id creates a new task.
struct TaskDraft {
    var id: String?
    var title: String
    var assigneeId: String?
    /// `yyyy-MM-dd` or nil for "no date".
    var dueOn: String?
    var cashCents: Int?
    /// `HH:mm`, only meaningful together with `dueOn`.
    var dueTime: String?
    /// Set when the task comes from a mail suggestion. Only used when creating.
    var source: MailSource?
}

/// Input of the calendar item form. A nil id creates a new item.
struct CalendarItemDraft {
    var id: String?
    var title: String
    var note: String
    var startsOn: String
    var time: TimeOfDay
    var weekdays: Set<Weekday>
    var repeatUntil: String?
    var skipHolidays: Bool
    var assigneeId: String?
    var cashCents: Int?
    /// Set when the item comes from a mail suggestion. Only used when creating.
    var source: MailSource?
}
