import Foundation
import Supabase

extension SupabaseDataSource {
    /// The driver, the changes of single days, the reminder, the notes and the label are extras that need their
    /// migrations: if one cannot be read, the week still loads and that part is simply empty.
    func loadPickupExtras(into data: inout CalendarData) async {
        let driverRows: [PickupDriverRow] = (try? await client.from("pickup_drivers")
            .select("day,driver")
            .execute().value) ?? []
        let overrideRows: [PickupOverrideRow] = (try? await client.from("pickup_overrides")
            .select("day,pickup_time")
            .execute().value) ?? []
        let reminderRows: [PickupReminderRow] = (try? await client.from("pickup_times")
            .select("remind_minutes")
            .execute().value) ?? []
        let noteRows: [PickupNoteRow] = (try? await client.from("pickup_notes")
            .select("weekday,valid_from,note")
            .execute().value) ?? []
        let noteDayRows: [PickupNoteOverrideRow] = (try? await client.from("pickup_note_overrides")
            .select("day,note")
            .execute().value) ?? []
        let labelRows: [FamilyLabelRow] = (try? await client.from("families")
            .select("pickup_label")
            .execute().value) ?? []
        let lastWins: (String, String) -> String = { _, last in last }
        data.pickupDrivers = Dictionary(driverRows.map { ($0.day, $0.driverId) }, uniquingKeysWith: lastWins)
        data.pickupOverrides = Dictionary(
            overrideRows.map { ($0.day, $0.override) },
            uniquingKeysWith: { _, last in last }
        )
        data.remindMinutes = reminderRows.first?.remindMinutes ?? 30
        data.pickupNotes = noteRows.compactMap(\.model)
        data.pickupNoteOverrides = Dictionary(noteDayRows.map { ($0.day, $0.note) }, uniquingKeysWith: lastWins)
        data.pickupLabel = labelRows.first?.pickupLabel ?? "Pickup"
    }
}
