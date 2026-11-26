import Foundation

/// Turns stored items, pickup times and holidays into the plan of one concrete week.
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

    static func plan(data: CalendarData, weekStart: Date, calendar: Calendar) -> WeekPlan {
        var itemsByDay: [Weekday: [WeekItem]] = [:]
        var holidayNames: [Weekday: String] = [:]
        var driverByDay: [Weekday: String] = [:]
        var overrideByDay: [Weekday: PickupOverride] = [:]
        for day in Weekday.allCases {
            let dayText = isoString(date(of: day, weekStart: weekStart, calendar: calendar), calendar: calendar)
            let holiday = data.holidays.first { $0.contains(dayText) }
            if let holiday { holidayNames[day] = holiday.name }
            if holiday == nil, let driver = data.pickupDrivers[dayText] { driverByDay[day] = driver }
            if holiday == nil, let change = data.pickupOverrides[dayText] { overrideByDay[day] = change }
            for item in data.items where occurs(item, on: dayText, as: day, inHoliday: holiday != nil) {
                itemsByDay[day, default: []].append(WeekItem(
                    id: "\(item.id)-\(dayText)",
                    time: item.time,
                    title: item.title,
                    note: item.note,
                    assignee: item.assignee,
                    tag: item.cashCents.map { .cash(cents: $0) },
                    sourceId: item.id
                ))
            }
        }
        var schedule = Self.schedule(from: data.pickups)
        schedule.pickupDays.subtract(holidayNames.keys)
        return WeekPlan(
            pickup: schedule, itemsByDay: itemsByDay, holidays: holidayNames, driverByDay: driverByDay,
            overrideByDay: overrideByDay
        )
    }

    private static func occurs(
        _ item: StoredCalendarItem,
        on dayText: String,
        as day: Weekday,
        inHoliday: Bool
    ) -> Bool {
        guard item.isSeries else { return item.startsOn == dayText }
        guard item.weekdays.contains(day), item.startsOn <= dayText else { return false }
        if let until = item.repeatUntil, dayText > until { return false }
        return !(item.skipHolidays && inHoliday)
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

    /// Value for the database, e.g. "07:30".
    var databaseValue: String { description }
}
