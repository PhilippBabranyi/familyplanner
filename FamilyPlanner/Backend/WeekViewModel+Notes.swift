import Foundation

// The "take along" notes and the family's name for the pickup.

@MainActor
extension WeekViewModel {
    /// The texts of the rhythm that counts on a day, by weekday.
    func rhythmTexts(on date: Date, child: String? = nil) -> [Weekday: String] {
        let calendar = WeekBuilder.calendar()
        let dayText = WeekBuilder.isoString(date, calendar: calendar)
        var texts: [Weekday: String] = [:]
        for day in Weekday.allCases {
            texts[day] = PickupNotes.rhythm(on: dayText, weekday: day, notes: calendarData(for: child).pickupNotes)
        }
        return texts
    }

    /// Starts a new rhythm on `startDate`. Earlier days keep what was valid then.
    func saveRhythm(from startDate: Date, texts: [Weekday: String], child: String? = nil) async -> Bool {
        let dayText = FormDates.iso(startDate)
        let rows = PickupNotes.rows(startingOn: dayText, texts: texts, current: calendarData(for: child).pickupNotes)
        if rows.isEmpty { return true }
        return await change("Die Hinweise konnten nicht gespeichert werden.") {
            try await $0.setPickupNotes(rows, child: child)
        }
    }

    /// Sets what to take along on one day of the shown week. Nil goes back to the rhythm; an empty text means
    /// nothing that day.
    func setBringNote(day: Weekday, note: String?, child: String? = nil) async -> Bool {
        let dayText = FormDates.iso(shownDate(of: day))
        return await change("Der Hinweis konnte nicht gespeichert werden.") {
            try await $0.setPickupNoteOverride(day: dayText, note: note, child: child)
        }
    }
}
