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

struct ShoppingRow: Decodable {
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
            due: DueText.make(from: dueOn),
            status: TaskStatus(databaseValue: status) ?? .open
        )
    }
}

extension ShoppingRow {
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
