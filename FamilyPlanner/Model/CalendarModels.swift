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

/// Everything the week and today screens are built from.
struct CalendarData {
    var items: [StoredCalendarItem] = []
    var pickups: [Weekday: TimeOfDay] = [:]
    var holidays: [Holiday] = []
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
}
