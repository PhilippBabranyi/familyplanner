// What has to be taken along on a school day ("Buch zurückbringen"), and how it is looked up for a day.

/// A note for a weekday, valid from `validFrom` (`yyyy-MM-dd`) until a later note for the same weekday starts.
/// An empty note means: nothing to take along from that day on.
struct PickupNote: Equatable {
    var weekday: Weekday
    var validFrom: String
    var note: String
}

enum PickupNotes {
    /// The note of a day: the rhythm, plus the note for that single day ("Piano Book & Christmas Jumper").
    /// A single-day note that is empty means nothing is taken along that day. Nothing in holidays.
    static func bring(
        on dayText: String,
        weekday: Weekday,
        notes: [PickupNote],
        overrides: [String: String],
        inHoliday: Bool
    ) -> String? {
        if inHoliday { return nil }
        let usual = clean(rhythm(on: dayText, weekday: weekday, notes: notes))
        guard let single = overrides[dayText] else { return usual }
        guard let extra = clean(single) else { return nil }
        return [usual, extra].compactMap { $0 }.joined(separator: " & ")
    }

    /// The note of the rhythm that counts on a day, ignoring single-day notes.
    static func rhythm(on dayText: String, weekday: Weekday, notes: [PickupNote]) -> String {
        notes
            .filter { $0.weekday == weekday && $0.validFrom <= dayText }
            .max { $0.validFrom < $1.validFrom }?.note ?? ""
    }

    /// The rows to store for a new rhythm that starts on `dayText`. A weekday whose text is empty only gets a row
    /// if an earlier note has to be ended.
    static func rows(startingOn dayText: String, texts: [Weekday: String], current: [PickupNote]) -> [PickupNote] {
        Weekday.allCases.compactMap { day in
            let text = (texts[day] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            let before = rhythm(on: dayText, weekday: day, notes: current)
            guard text != before else { return nil }
            return PickupNote(weekday: day, validFrom: dayText, note: text)
        }
    }

    private static func clean(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
