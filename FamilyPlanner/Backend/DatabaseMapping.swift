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
    let assigneePerson: UUID?
    let dueOn: String?
    let dueTime: String?
    let status: String
    let cashCents: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, assignee, status
        case assigneePerson = "assignee_person"
        case dueOn = "due_on"
        case dueTime = "due_time"
        case cashCents = "cash_cents"
    }
}

/// A person of the household without an account (a child), as stored in `household_people`.
struct PersonRow: Decodable {
    let id: UUID
    let displayName: String

    enum CodingKeys: String, CodingKey {
        case id
        case displayName = "display_name"
    }
}

/// Names of everyone who can be responsible for something, by the id the database stores.
struct PeopleNames {
    var members: [UUID: String] = [:]
    var people: [UUID: String] = [:]

    func name(member: UUID?, person: UUID?) -> String? {
        if let member { return members[member] }
        if let person { return people[person] }
        return nil
    }

    /// The id the app uses for the picker: the user id, or `person:<id>` for a person without an account.
    static func memberId(member: UUID?, person: UUID?) -> String? {
        if let member { return member.uuidString }
        if let person { return Member.personPrefix + person.uuidString }
        return nil
    }
}

/// Splits the id of a picked member into the two assignee columns.
struct AssigneeColumns {
    let member: String?
    let person: String?

    init(memberId: String?) {
        if let person = Member.personId(from: memberId) {
            member = nil
            self.person = person
        } else {
            member = memberId
            person = nil
        }
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
    func makeItem(names: PeopleNames) -> TaskItem {
        TaskItem(
            id: id.uuidString,
            title: title,
            assignee: names.name(member: assignee, person: assigneePerson),
            assigneeId: PeopleNames.memberId(member: assignee, person: assigneePerson),
            dueOn: dueOn,
            dueTime: dueTime.flatMap { TimeOfDay(databaseValue: $0) }.map { $0.description },
            due: DueText.make(from: dueOn),
            status: TaskStatus(databaseValue: status) ?? .open,
            cashCents: cashCents
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
    let assigneePerson: UUID?
    let cashCents: Int?

    enum CodingKeys: String, CodingKey {
        case id, title, note, assignee, weekdays
        case assigneePerson = "assignee_person"
        case startsOn = "starts_on"
        case atTime = "at_time"
        case repeatUntil = "repeat_until"
        case skipHolidays = "skip_holidays"
        case cashCents = "cash_cents"
    }

    func makeItem(names: PeopleNames) -> StoredCalendarItem? {
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
            assigneeId: PeopleNames.memberId(member: assignee, person: assigneePerson),
            assignee: names.name(member: assignee, person: assigneePerson),
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

struct PickupReminderRow: Decodable {
    let remindMinutes: Int

    enum CodingKeys: String, CodingKey {
        case remindMinutes = "remind_minutes"
    }
}

struct PickupDriverRow: Decodable {
    let day: String
    let driver: UUID

    /// The id the app uses for this member (UUID.uuidString, upper case), so that the name can be found.
    var driverId: String { driver.uuidString }
}

struct PickupDriverWrite: Encodable {
    let familyId: UUID
    let day: String
    let driver: String

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case day
        case driver
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
    let assigneePerson: String?
    let dueOn: String?
    let dueTime: String?
    let cashCents: Int?

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case title, assignee
        case assigneePerson = "assignee_person"
        case dueOn = "due_on"
        case dueTime = "due_time"
        case cashCents = "cash_cents"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        // family_id is only sent when inserting; it never changes afterwards.
        if let familyId { try container.encode(familyId, forKey: .familyId) }
        try container.encode(title, forKey: .title)
        try container.encode(assignee, forKey: .assignee)
        try container.encode(assigneePerson, forKey: .assigneePerson)
        try container.encode(dueOn, forKey: .dueOn)
        // A time without a date is not allowed by the database.
        try container.encode(dueOn == nil ? nil : dueTime, forKey: .dueTime)
        try container.encode(cashCents, forKey: .cashCents)
    }
}

struct CalendarItemWrite: Encodable {
    let familyId: UUID?
    let draft: CalendarItemDraft

    enum CodingKeys: String, CodingKey {
        case familyId = "family_id"
        case title, note, assignee, weekdays
        case assigneePerson = "assignee_person"
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
        let columns = AssigneeColumns(memberId: draft.assigneeId)
        try container.encode(columns.member, forKey: .assignee)
        try container.encode(columns.person, forKey: .assigneePerson)
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

/// A row of `inbox_items` as the bell needs it.
struct InboxRow: Decodable {
    let id: UUID
    let sender: String
    let subject: String
    let link: String
    let suggestion: SuggestionPayload?

    func makeSuggestion() -> InboxSuggestion? {
        guard let suggestion else { return nil }
        return InboxSuggestion(id: id.uuidString, payload: suggestion, sender: sender, subject: subject, link: link)
    }
}
