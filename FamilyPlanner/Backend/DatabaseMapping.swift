import Foundation

extension TaskStatus {
    /// Value stored in the `tasks.status` column.
    var databaseValue: String {
        switch self {
        case .open: return "open"
        case .doing: return "doing"
        case .done: return "done"
        }
    }

    init?(databaseValue: String) {
        guard let match = Self.allCases.first(where: { $0.databaseValue == databaseValue }) else { return nil }
        self = match
    }
}

extension ShoppingGroup {
    /// Value stored in the `shopping_items.category` column.
    var databaseValue: String {
        switch self {
        case .produce: return "produce"
        case .baking: return "baking"
        case .household: return "household"
        case .other: return "other"
        }
    }

    init(databaseValue: String) {
        self = Self.allCases.first(where: { $0.databaseValue == databaseValue }) ?? .other
    }
}

enum DueText {
    /// "bis 28.11." for a date in `yyyy-MM-dd` format, "ohne Datum" for nil or unreadable values.
    static func make(from isoDate: String?) -> String {
        guard let isoDate else { return "ohne Datum" }
        let parts = isoDate.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) else { return "ohne Datum" }
        return "bis \(day).\(month)."
    }
}

extension DueText {
    /// "2026-12-23" to "23.12.". Unreadable values are returned unchanged.
    static func short(_ isoDate: String) -> String {
        let parts = isoDate.split(separator: "-")
        guard parts.count == 3, let month = Int(parts[1]), let day = Int(parts[2]) else { return isoDate }
        return "\(day).\(month)."
    }
}

struct TaskRow: Decodable {
    let id: UUID
    let title: String
    let assignee: UUID?
    let dueOn: String?
    let status: String

    enum CodingKeys: String, CodingKey {
        case id, title, assignee, status
        case dueOn = "due_on"
    }
}

struct MemberRow: Decodable {
    let familyId: UUID
    let userId: UUID
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case userId = "user_id"
        case displayName = "display_name"
    }
}

struct ShoppingItemRow: Decodable {
    let id: UUID
    let name: String
    let quantity: String
    let category: String
    let inBasket: Bool
    let label: String?

    enum CodingKeys: String, CodingKey {
        case id, name, quantity, category, label
        case inBasket = "in_basket"
    }
}

struct NewShoppingRow: Encodable {
    let familyId: UUID
    let name: String

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case name
    }
}

extension TaskRow {
    func makeItem(memberNames: [UUID: String]) -> TaskItem {
        TaskItem(
            id: id.uuidString,
            title: title,
            assignee: assignee.flatMap { memberNames[$0] },
            assigneeId: assignee?.uuidString,
            dueOn: dueOn,
            due: DueText.make(from: dueOn),
            status: TaskStatus(databaseValue: status) ?? .open
        )
    }
}

extension ShoppingItemRow {
    func makeItem() -> ShoppingItem {
        ShoppingItem(
            id: id.uuidString,
            name: name,
            quantity: quantity,
            group: ShoppingGroup(databaseValue: category),
            isInBasket: inBasket,
            label: label
        )
    }
}

struct CalendarItemRow: Decodable {
    let id: UUID
    let title: String
    let note: String?
    let startsOn: String
    let atTime: String
    let weekdays: [Int]
    let repeatUntil: String?
    let skipHolidays: Bool
    let assignee: UUID?
    let cashCents: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, note, assignee, weekdays
        case startsOn = "starts_on"
        case atTime = "at_time"
        case repeatUntil = "repeat_until"
        case skipHolidays = "skip_holidays"
        case cashCents = "cash_cents"
    }

    func makeItem(memberNames: [UUID: String]) -> StoredCalendarItem? {
        guard let time = TimeOfDay(databaseValue: atTime) else { return nil }
        return StoredCalendarItem(
            id: id.uuidString,
            title: title,
            note: note,
            startsOn: startsOn,
            time: time,
            weekdays: Set(weekdays.compactMap { Weekday(rawValue: $0) }),
            repeatUntil: repeatUntil,
            skipHolidays: skipHolidays,
            assigneeId: assignee?.uuidString,
            assignee: assignee.flatMap { memberNames[$0] },
            cashCents: cashCents
        )
    }
}

struct PickupRow: Decodable {
    let weekday: Int
    let pickupTime: String

    enum CodingKeys: String, CodingKey {
        case weekday
        case pickupTime = "pickup_time"
    }
}

struct HolidayRow: Decodable {
    let id: UUID
    let name: String
    let startsOn: String
    let endsOn: String

    enum CodingKeys: String, CodingKey {
        case id, name
        case startsOn = "starts_on"
        case endsOn = "ends_on"
    }

    func makeHoliday() -> Holiday {
        Holiday(id: id.uuidString, name: name, startsOn: startsOn, endsOn: endsOn)
    }
}

// MARK: - Writes
//
// Optional values are encoded explicitly (as null) so that an update can clear a field.

struct TaskWrite: Encodable {
    let familyId: UUID?
    let title: String
    let assignee: String?
    let dueOn: String?

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case title, assignee
        case dueOn = "due_on"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // family_id is only sent when inserting; it never changes afterwards.
        if let familyId { try container.encode(familyId, forKey: .familyId) }
        try container.encode(title, forKey: .title)
        try container.encode(assignee, forKey: .assignee)
        try container.encode(dueOn, forKey: .dueOn)
    }
}

struct CalendarItemWrite: Encodable {
    let familyId: UUID?
    let draft: CalendarItemDraft

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case title, note, assignee, weekdays
        case startsOn = "starts_on"
        case atTime = "at_time"
        case repeatUntil = "repeat_until"
        case skipHolidays = "skip_holidays"
        case cashCents = "cash_cents"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        if let familyId { try container.encode(familyId, forKey: .familyId) }
        try container.encode(draft.title, forKey: .title)
        let note = draft.note.trimmingCharacters(in: .whitespacesAndNewlines)
        try container.encode(note.isEmpty ? nil : note, forKey: .note)
        try container.encode(draft.startsOn, forKey: .startsOn)
        try container.encode(draft.time.databaseValue, forKey: .atTime)
        try container.encode(draft.weekdays.map(\.rawValue).sorted(), forKey: .weekdays)
        try container.encode(draft.repeatUntil, forKey: .repeatUntil)
        try container.encode(draft.skipHolidays, forKey: .skipHolidays)
        try container.encode(draft.assigneeId, forKey: .assignee)
        try container.encode(draft.cashCents, forKey: .cashCents)
    }
}

struct PickupWrite: Encodable {
    let familyId: UUID
    let weekday: Int
    let pickupTime: String

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case weekday
        case pickupTime = "pickup_time"
    }
}

struct HolidayWrite: Encodable {
    let familyId: UUID
    let name: String
    let startsOn: String
    let endsOn: String

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case name
        case startsOn = "starts_on"
        case endsOn = "ends_on"
    }
}
