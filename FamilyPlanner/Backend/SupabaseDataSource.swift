import Foundation
import Supabase

enum DataSourceError: Error {
    case noFamily
}

/// Reads and writes the family's data. Row-level security in the database decides what is allowed.
actor SupabaseDataSource: FamilyDataSource {
    let client: SupabaseClient
    private var cachedFamilyId: UUID?

    init(client: SupabaseClient) {
        self.client = client
    }

    // MARK: Tasks

    func loadTasks() async throws -> TaskBoard {
        let rows: [TaskRow] = try await client.from("tasks")
            .select("id,title,assignee,assignee_person,due_on,due_time,status,cash_cents")
            .order("created_at")
            .execute().value
        let names = try await peopleNames()
        let sources = await loadSources(table: "tasks")
        return TaskBoard(tasks: rows.map {
            var item = $0.makeItem(names: names)
            item.source = sources[item.id]
            return item
        })
    }

    func setTaskStatus(id: String, status: TaskStatus) async throws {
        guard let uuid = UUID(uuidString: id) else { return }
        try await client.rpc("set_task_status", params: [
            "task_id": uuid.uuidString,
            "new_status": status.databaseValue
        ]).execute()
    }

    func saveTask(_ draft: TaskDraft) async throws {
        if let id = draft.id {
            let columns = AssigneeColumns(memberId: draft.assigneeId)
            let write = TaskWrite(
                familyId: nil, title: draft.title, assignee: columns.member, assigneePerson: columns.person,
                dueOn: draft.dueOn, dueTime: draft.dueTime, cashCents: draft.cashCents
            )
            try await client.from("tasks").update(write).eq("id", value: id).execute()
        } else {
            let columns = AssigneeColumns(memberId: draft.assigneeId)
            let write = TaskWrite(
                familyId: try await familyId(), title: draft.title,
                assignee: columns.member, assigneePerson: columns.person,
                dueOn: draft.dueOn, dueTime: draft.dueTime, cashCents: draft.cashCents, source: draft.source
            )
            try await client.from("tasks").insert(write).execute()
        }
    }

    func deleteTask(id: String) async throws {
        try await client.from("tasks").delete().eq("id", value: id).execute()
    }

    // MARK: Mail suggestions and push

    func loadSuggestions() async throws -> [InboxSuggestion] {
        let rows: [InboxRow] = try await client.from("inbox_items")
            .select("id,sender,subject,link,suggestion")
            .eq("status", value: "new")
            .order("received_at", ascending: false)
            .execute().value
        return rows.compactMap { $0.makeSuggestion() }
    }

    func decideSuggestion(id: String, decision: SuggestionDecision) async throws {
        try await client.from("inbox_items")
            .update(["status": decision.databaseValue])
            .eq("id", value: id)
            .execute()
    }

    func registerDevice(token: String) async throws {
        try await client.rpc("register_device", params: ["device_token": token]).execute()
    }

    // MARK: Shopping

    func loadShoppingList() async throws -> ShoppingList {
        let rows: [ShoppingItemRow] = try await client.from("shopping_items")
            .select("id,name,quantity,category,in_basket,label")
            .order("created_at")
            .execute().value
        return ShoppingList(items: rows.map { $0.makeItem() })
    }

    func addShoppingItem(name: String) async throws -> ShoppingItem {
        let familyId = try await familyId()
        let row: ShoppingItemRow = try await client.from("shopping_items")
            .insert(NewShoppingRow(familyId: familyId, name: name))
            .select("id,name,quantity,category,in_basket,label")
            .single()
            .execute().value
        return row.makeItem()
    }

    func setInBasket(id: String, inBasket: Bool) async throws {
        try await client.from("shopping_items")
            .update(["in_basket": inBasket])
            .eq("id", value: id)
            .execute()
    }

    // MARK: Calendar

    func loadCalendar() async throws -> CalendarData {
        let rows: [CalendarItemRow] = try await client.from("calendar_items")
            .select(
                "id,title,note,starts_on,at_time,weekdays,repeat_until,skip_holidays,"
                    + "assignee,assignee_person,cash_cents"
            )
            .execute().value
        let pickupRows: [PickupRow] = try await client.from("pickup_times")
            .select("weekday,pickup_time")
            .execute().value
        let holidayRows: [HolidayRow] = try await client.from("holidays")
            .select("id,name,starts_on,ends_on")
            .order("starts_on")
            .execute().value
        let names = try await peopleNames()
        let sources = await loadSources(table: "calendar_items")
        var pickups: [Weekday: TimeOfDay] = [:]
        for row in pickupRows {
            if let day = Weekday(rawValue: row.weekday), let time = TimeOfDay(databaseValue: row.pickupTime) {
                pickups[day] = time
            }
        }
        // The driver and the reminder are optional extras: if they cannot be read, the week still loads.
        let driverRows: [PickupDriverRow] = (try? await client.from("pickup_drivers")
            .select("day,driver")
            .execute().value) ?? []
        let overrideRows: [PickupOverrideRow] = (try? await client.from("pickup_overrides")
            .select("day,pickup_time")
            .execute().value) ?? []
        let reminderRows: [PickupReminderRow] = (try? await client.from("pickup_times")
            .select("remind_minutes")
            .execute().value) ?? []
        return CalendarData(
            items: rows.compactMap { row in
                var item = row.makeItem(names: names)
                item?.source = sources[row.id.uuidString]
                return item
            },
            pickups: pickups,
            holidays: holidayRows.map { $0.makeHoliday() },
            pickupDrivers: Dictionary(driverRows.map { ($0.day, $0.driverId) }, uniquingKeysWith: { _, last in last }),
            pickupOverrides: Dictionary(
                overrideRows.map { ($0.day, $0.override) },
                uniquingKeysWith: { _, last in last }
            ),
            remindMinutes: reminderRows.first?.remindMinutes ?? 30
        )
    }

    func saveCalendarItem(_ draft: CalendarItemDraft) async throws {
        if let id = draft.id {
            try await client.from("calendar_items")
                .update(CalendarItemWrite(familyId: nil, draft: draft))
                .eq("id", value: id)
                .execute()
        } else {
            try await client.from("calendar_items")
                .insert(CalendarItemWrite(familyId: try await familyId(), draft: draft))
                .execute()
        }
    }

    func deleteCalendarItem(id: String) async throws {
        try await client.from("calendar_items").delete().eq("id", value: id).execute()
    }

    func setPickupTimes(_ times: [Weekday: TimeOfDay]) async throws {
        let familyId = try await familyId()
        let rows = times.map {
            PickupWrite(familyId: familyId, weekday: $0.key.rawValue, pickupTime: $0.value.databaseValue)
        }
        if !rows.isEmpty {
            try await client.from("pickup_times").upsert(rows, onConflict: "family_id,weekday").execute()
        }
        for day in Weekday.allCases where times[day] == nil {
            try await client.from("pickup_times").delete().eq("weekday", value: day.rawValue).execute()
        }
    }

    func setPickupDriver(day: String, memberId: String?) async throws {
        guard let memberId else {
            try await client.from("pickup_drivers").delete().eq("day", value: day).execute()
            return
        }
        guard let driver = UUID(uuidString: memberId) else { return }
        let write = PickupDriverWrite(familyId: try await familyId(), day: day, driver: driver.uuidString.lowercased())
        try await client.from("pickup_drivers").upsert(write, onConflict: "family_id,day").execute()
    }

    func setPickupOverride(day: String, override: PickupOverride?) async throws {
        guard let override else {
            try await client.from("pickup_overrides").delete().eq("day", value: day).execute()
            return
        }
        var time: String?
        if case let .time(value) = override { time = value.databaseValue }
        let write = PickupOverrideWrite(familyId: try await familyId(), day: day, pickupTime: time)
        try await client.from("pickup_overrides").upsert(write, onConflict: "family_id,day").execute()
    }

    func setPickupReminder(minutes: Int) async throws {
        try await client.from("pickup_times")
            .update(["remind_minutes": minutes])
            .gte("weekday", value: 1)
            .execute()
    }

    func addHoliday(name: String, startsOn: String, endsOn: String) async throws {
        let write = HolidayWrite(familyId: try await familyId(), name: name, startsOn: startsOn, endsOn: endsOn)
        try await client.from("holidays").insert(write).execute()
    }

    func deleteHoliday(id: String) async throws {
        try await client.from("holidays").delete().eq("id", value: id).execute()
    }

    // MARK: People

    func loadMembers() async throws -> [Member] {
        let names = try await peopleNames()
        let accounts = names.members.map { Member(id: $0.key.uuidString, name: $0.value) }
        let people = names.people.map { Member(id: Member.personPrefix + $0.key.uuidString, name: $0.value) }
        return (accounts + people).sorted { $0.name < $1.name }
    }

    func currentMemberName() async throws -> String? {
        let userId = try await client.auth.session.user.id
        return try await memberNames()[userId]
    }

    // MARK: Helpers

    private func peopleNames() async throws -> PeopleNames {
        let rows: [PersonRow] = try await client.from("household_people")
            .select("id,display_name")
            .execute().value
        return PeopleNames(
            members: try await memberNames(),
            people: Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0.displayName) })
        )
    }

    private func memberNames() async throws -> [UUID: String] {
        let members: [MemberRow] = try await client.from("family_members")
            .select("family_id,user_id,display_name")
            .execute().value
        return Dictionary(uniqueKeysWithValues: members.map { ($0.userId, $0.displayName) })
    }

    private func familyId() async throws -> UUID {
        if let cachedFamilyId { return cachedFamilyId }
        let members: [MemberRow] = try await client.from("family_members")
            .select("family_id,user_id,display_name")
            .limit(1)
            .execute().value
        guard let first = members.first else { throw DataSourceError.noFamily }
        cachedFamilyId = first.familyId
        return first.familyId
    }
}
