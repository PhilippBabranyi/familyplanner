import Foundation

// The "take along" notes and the family's name for the pickup.

@MainActor
extension WeekViewModel {
    /// How the family calls the pickup, e.g. "Pickup".
    var pickupLabel: String { data.pickupLabel }

    /// The texts of the rhythm that counts on a day, by weekday.
    func rhythmTexts(on date: Date) -> [Weekday: String] {
        let calendar = WeekBuilder.calendar()
        let dayText = WeekBuilder.isoString(date, calendar: calendar)
        var texts: [Weekday: String] = [:]
        for day in Weekday.allCases {
            texts[day] = PickupNotes.rhythm(on: dayText, weekday: day, notes: data.pickupNotes)
        }
        return texts
    }

    /// Starts a new rhythm on `startDate`. Earlier days keep what was valid then.
    func saveRhythm(from startDate: Date, texts: [Weekday: String]) async -> Bool {
        let dayText = FormDates.iso(startDate)
        let rows = PickupNotes.rows(startingOn: dayText, texts: texts, current: data.pickupNotes)
        if rows.isEmpty { return true }
        return await change("Die Hinweise konnten nicht gespeichert werden.") { try await $0.setPickupNotes(rows) }
    }

    /// Sets what to take along on one day of the shown week. Nil goes back to the rhythm; an empty text means
    /// nothing that day.
    func setBringNote(day: Weekday, note: String?) async -> Bool {
        let dayText = FormDates.iso(shownDate(of: day))
        return await change("Der Hinweis konnte nicht gespeichert werden.") {
            try await $0.setPickupNoteOverride(day: dayText, note: note)
        }
    }
}
