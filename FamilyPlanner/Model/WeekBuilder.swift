import Foundation

/// A calendar item as stored in the database, before it is placed in a concrete week.
struct StoredCalendarItem {
    let id: String
    let title: String
    let note: String?
    /// First (or only) day, `yyyy-MM-dd`.
    let startsOn: String
    let time: TimeOfDay
    let repeatsWeekly: Bool
    let assignee: String?
    let cashCents: Int?
}

/// Turns stored items and pickup times into the plan of one concrete week.
enum WeekBuilder {
    static func calendar() -> Calendar {
        var calendar = Calendar(identifier: .iso8601)
        calendar.locale = Locale(identifier: "de_DE")
        return calendar
    }

    static func isoString(_ date: Date, calendar: Calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    static func date(fromISO text: String, calendar: Calendar) -> Date? {
        let parts = text.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
    }

    /// Monday (start of day) of the week that contains `date`.
    static func weekStart(containing date: Date, calendar: Calendar) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    static func weekday(of date: Date, calendar: Calendar) -> Weekday {
        // Calendar weekday: 1 = Sunday ... 7 = Saturday. Weekday: 1 = Monday ... 7 = Sunday.
        let raw = calendar.component(.weekday, from: date)
        return Weekday(rawValue: raw == 1 ? 7 : raw - 1) ?? .monday
    }

    /// The date of `day` in the week starting at `weekStart`.
    static func date(of day: Weekday, weekStart: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: day.rawValue - 1, to: weekStart) ?? weekStart
    }

    static func plan(
        items: [StoredCalendarItem],
        pickups: [Weekday: TimeOfDay],
        weekStart: Date,
        calendar: Calendar
    ) -> WeekPlan {
        var itemsByDay: [Weekday: [WeekItem]] = [:]
        for day in Weekday.allCases {
            let dayDate = date(of: day, weekStart: weekStart, calendar: calendar)
            let dayText = isoString(dayDate, calendar: calendar)
            for item in items where occurs(item, on: dayText, as: day, calendar: calendar) {
                itemsByDay[day, default: []].append(WeekItem(
                    id: "\(item.id)-\(dayText)",
                    time: item.time,
                    title: item.title,
                    note: item.note,
                    assignee: item.assignee,
                    tag: item.cashCents.map { .cash(cents: $0) }
                ))
            }
        }
        return WeekPlan(pickup: schedule(from: pickups), itemsByDay: itemsByDay)
    }

    private static func occurs(
        _ item: StoredCalendarItem,
        on dayText: String,
        as day: Weekday,
        calendar: Calendar
    ) -> Bool {
        if item.startsOn == dayText { return true }
        guard item.repeatsWeekly, item.startsOn < dayText,
              let start = date(fromISO: item.startsOn, calendar: calendar) else { return false }
        return weekday(of: start, calendar: calendar) == day
    }

    /// The most common pickup time becomes the default, all other times are exceptions.
    static func schedule(from pickups: [Weekday: TimeOfDay]) -> PickupSchedule {
        let counts = Dictionary(grouping: pickups.values, by: { $0 }).mapValues(\.count)
        let defaultTime = counts.max { lhs, rhs in
            lhs.value == rhs.value ? lhs.key > rhs.key : lhs.value < rhs.value
        }?.key ?? .at(15, 0)
        return PickupSchedule(
            pickupDays: Set(pickups.keys),
            defaultTime: defaultTime,
            exceptions: pickups.filter { $0.value != defaultTime }
        )
    }
}

extension TimeOfDay {
    /// Parses database times such as "15:20:00" or "15:20".
    init?(databaseValue: String) {
        let parts = databaseValue.split(separator: ":").compactMap { Int($0) }
        guard parts.count >= 2 else { return nil }
        self.init(hour: parts[0], minute: parts[1])
    }
}
