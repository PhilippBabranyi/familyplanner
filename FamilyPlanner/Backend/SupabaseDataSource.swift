import Foundation
import Supabase

enum DataSourceError: Error {
    case noFamily
}

/// Reads and writes the family's data. Row-level security in the database decides what is visible.
actor SupabaseDataSource: FamilyDataSource {
    private let client: SupabaseClient
    private var cachedFamilyId: UUID?

    init(client: SupabaseClient) {
        self.client = client
    }

    func loadTasks() async throws -> TaskBoard {
        let rows: [TaskRow] = try await client.from("tasks")
            .select("id,title,assignee,due_on,status")
            .order("created_at")
            .execute().value
        let members: [MemberRow] = try await client.from("family_members")
            .select("family_id,user_id,display_name")
            .execute().value
        let names = Dictionary(uniqueKeysWithValues: members.map { ($0.userId, $0.displayName) })
        return TaskBoard(tasks: rows.map { $0.makeItem(memberNames: names) })
    }

    func setTaskStatus(id: String, status: TaskStatus) async throws {
        guard let uuid = UUID(uuidString: id) else { return }
        try await client.rpc("set_task_status", params: [
            "task_id": uuid.uuidString,
            "new_status": status.databaseValue
        ]).execute()
    }

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

    func loadWeek(starting weekStart: Date) async throws -> WeekPlan {
        let rows: [CalendarItemRow] = try await client.from("calendar_items")
            .select("id,title,note,starts_on,at_time,repeats_weekly,assignee,cash_cents")
            .execute().value
        let pickupRows: [PickupRow] = try await client.from("pickup_times")
            .select("weekday,pickup_time")
            .execute().value
        let names = try await memberNames()
        let items = rows.compactMap { $0.makeItem(memberNames: names) }
        var pickups: [Weekday: TimeOfDay] = [:]
        for row in pickupRows {
            if let day = Weekday(rawValue: row.weekday), let time = TimeOfDay(databaseValue: row.pickupTime) {
                pickups[day] = time
            }
        }
        return WeekBuilder.plan(
            items: items,
            pickups: pickups,
            weekStart: weekStart,
            calendar: WeekBuilder.calendar()
        )
    }

    func currentMemberName() async throws -> String? {
        let userId = try await client.auth.session.user.id
        return try await memberNames()[userId]
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
