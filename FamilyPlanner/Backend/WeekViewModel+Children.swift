import Foundation

// The pickup of the children. Every function that is about one child takes the child's id; nil means the first
// child, which is what the screens use as long as there is only one.

@MainActor
extension WeekViewModel {
    /// The data of the first child (or without pickup data if no child is set up).
    var data: CalendarData { calendars.first ?? CalendarData() }

    /// The children that have a pickup.
    var children: [PickupChild] { calendars.compactMap(\.child) }

    /// The data of one child; the first child's if the id is nil or unknown.
    func calendarData(for child: String?) -> CalendarData {
        calendars.first { $0.child?.id == child } ?? data
    }

    /// The plan of the current week (items and the pickup of one child).
    func weekPlan(for child: String? = nil) -> WeekPlan {
        WeekBuilder.plan(data: calendarData(for: child), weekStart: weekStart, calendar: calendar)
    }

    var plan: WeekPlan { weekPlan() }

    /// The plan of the week that the week screen shows.
    func shownWeekPlan(for child: String? = nil) -> WeekPlan {
        WeekBuilder.plan(data: calendarData(for: child), weekStart: shownWeekStart, calendar: calendar)
    }

    var shownPlan: WeekPlan { shownWeekPlan() }

    /// How the pickup is called, e.g. "Pickup Kim".
    func childLabel(for child: String? = nil) -> String { calendarData(for: child).pickupLabel }

    var pickupLabel: String { childLabel() }

    func savePickups(_ times: [Weekday: TimeOfDay], remindMinutes: Int? = nil, child: String? = nil) async -> Bool {
        await change("Die Abholzeiten konnten nicht gespeichert werden.") {
            try await $0.setPickupTimes(times, child: child)
            if let remindMinutes { try await $0.setPickupReminder(minutes: remindMinutes, child: child) }
        }
    }

    /// Enters who picks up on a day of the shown week, or nobody (nil).
    func setPickupDriver(day: Weekday, memberId: String?, child: String? = nil) async -> Bool {
        await setPickupDriver(dayText: FormDates.iso(shownDate(of: day)), memberId: memberId, child: child)
    }

    /// Enters who picks up on any day (`yyyy-MM-dd`), or nobody (nil).
    func setPickupDriver(dayText: String, memberId: String?, child: String? = nil) async -> Bool {
        await change("Der Pickup konnte nicht gespeichert werden.") {
            try await $0.setPickupDriver(day: dayText, memberId: memberId, child: child)
        }
    }

    /// Changes the pickup of one day of the shown week; nil goes back to the weekly time.
    func setPickupOverride(day: Weekday, override: PickupOverride?, child: String? = nil) async -> Bool {
        let dayText = FormDates.iso(shownDate(of: day))
        return await change("Die Abholzeit konnte nicht gespeichert werden.") {
            try await $0.setPickupOverride(day: dayText, override: override, child: child)
        }
    }

    /// Name of the person who picks up on a day of the shown week.
    func driverName(on day: Weekday, child: String? = nil) -> String? {
        accountName(shownWeekPlan(for: child).driverByDay[day])
    }

    /// Pickups of today (if not yet over) and tomorrow that nobody has taken over. They show up in the bell.
    func openPickups(now: Date = Date()) -> [OpenPickup] {
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let current = TimeOfDay.at(parts.hour ?? 0, parts.minute ?? 0)
        var result: [OpenPickup] = []
        for entry in calendars {
            for offset in 0...1 {
                guard let date = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
                let start = WeekBuilder.weekStart(containing: date, calendar: calendar)
                let entryPlan = WeekBuilder.plan(data: entry, weekStart: start, calendar: calendar)
                let day = WeekBuilder.weekday(of: date, calendar: calendar)
                guard entryPlan.pickupMark(on: day) == .open, let time = entryPlan.pickupTime(on: day) else { continue }
                if offset == 0 && time < current { continue }
                let dayText = WeekBuilder.isoString(date, calendar: calendar)
                result.append(OpenPickup(dayText: dayText, time: time, isToday: offset == 0, child: entry.child))
            }
        }
        return result
    }

    /// Today's pickups, one per child that has one.
    var todayPickups: [TodayPickup] {
        calendars.compactMap { entry in
            let entryPlan = weekPlan(for: entry.child?.id)
            guard let time = entryPlan.pickupTime(on: todayWeekday), let mark = entryPlan.pickupMark(on: todayWeekday)
            else { return nil }
            return TodayPickup(
                label: entry.pickupLabel, time: time,
                driver: accountName(entryPlan.driverByDay[todayWeekday]), mark: mark
            )
        }
    }

    /// Today's pickup of the first child, nil if there is none.
    var todayPickup: TodayPickup? { todayPickups.first }

    /// The dot of a day of the shown week: the most urgent mark of all children (open, then changed, then assigned).
    func shownDot(on weekday: Weekday) -> (mark: PickupMark, driver: String?)? {
        let marks = calendars.compactMap { entry -> (PickupMark, String?)? in
            let entryPlan = shownWeekPlan(for: entry.child?.id)
            guard let mark = entryPlan.pickupMark(on: weekday) else { return nil }
            return (mark, accountName(entryPlan.driverByDay[weekday]))
        }
        for urgent in [PickupMark.open, .changed] {
            if let found = marks.first(where: { $0.0 == urgent }) { return found }
        }
        return marks.first
    }

    func accountName(_ id: String?) -> String? {
        guard let id else { return nil }
        return accounts.first { $0.id == id }?.name ?? "jemand"
    }
}
