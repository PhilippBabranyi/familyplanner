import Foundation
import Supabase

extension SupabaseDataSource {
    /// The children that have a pickup, by name. Without the migration (or without a marked child) there are none:
    /// the week then simply shows no pickup.
    func loadPickupChildren() async -> [PickupChild] {
        let rows: [PickupChildRow] = (try? await client.from("household_people")
            .select("id,display_name")
            .eq("has_pickup", value: true)
            .execute().value) ?? []
        return rows.map(\.model).sorted { $0.name < $1.name }
    }

    /// The pickup data of one child: times, driver, changes of single days, reminder and notes. These are extras:
    /// if one cannot be read, the week still loads and that part is simply empty.
    func loadPickup(of child: PickupChild, into data: inout CalendarData) async {
        let id = child.id
        let timeRows: [PickupRow] = (try? await client.from("pickup_times")
            .select("weekday,pickup_time").eq("person_id", value: id)
            .execute().value) ?? []
        let driverRows: [PickupDriverRow] = (try? await client.from("pickup_drivers")
            .select("day,driver").eq("person_id", value: id)
            .execute().value) ?? []
        let overrideRows: [PickupOverrideRow] = (try? await client.from("pickup_overrides")
            .select("day,pickup_time").eq("person_id", value: id)
            .execute().value) ?? []
        let reminderRows: [PickupReminderRow] = (try? await client.from("pickup_times")
            .select("remind_minutes").eq("person_id", value: id)
            .execute().value) ?? []
        let noteRows: [PickupNoteRow] = (try? await client.from("pickup_notes")
            .select("weekday,valid_from,note").eq("person_id", value: id)
            .execute().value) ?? []
        let noteDayRows: [PickupNoteOverrideRow] = (try? await client.from("pickup_note_overrides")
            .select("day,note").eq("person_id", value: id)
            .execute().value) ?? []
        let lastWins: (String, String) -> String = { _, last in last }
        data.child = child
        for row in timeRows {
            if let day = Weekday(rawValue: row.weekday), let time = TimeOfDay(databaseValue: row.pickupTime) {
                data.pickups[day] = time
            }
        }
        data.pickupDrivers = Dictionary(driverRows.map { ($0.day, $0.driverId) }, uniquingKeysWith: lastWins)
        data.pickupOverrides = Dictionary(
            overrideRows.map { ($0.day, $0.override) },
            uniquingKeysWith: { _, last in last }
        )
        data.remindMinutes = reminderRows.first?.remindMinutes ?? 30
        data.pickupNotes = noteRows.compactMap(\.model)
        data.pickupNoteOverrides = Dictionary(noteDayRows.map { ($0.day, $0.note) }, uniquingKeysWith: lastWins)
    }

    /// The child a write is for: the given one, or the first child with a pickup.
    func pickupChildId(_ child: String?) async throws -> UUID {
        if let child, let id = UUID(uuidString: child) { return id }
        guard let first = await loadPickupChildren().first, let id = UUID(uuidString: first.id) else {
            throw DataSourceError.noChild
        }
        return id
    }
}
