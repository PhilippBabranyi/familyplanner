import Foundation

enum ShoppingGroup: String, CaseIterable {
    case produce = "Obst & Gemüse"
    case baking = "Backen"
    case household = "Haushalt"
    case other = "Sonstiges"
}

struct ShoppingItem: Identifiable {
    let id: String
    var name: String
    var quantity: String = ""
    var group: ShoppingGroup
    var isInBasket = false
    /// Optional context, e.g. the occasion the item is for.
    var label: String?
}

struct ShoppingList {
    struct Section: Identifiable {
        let title: String
        let items: [ShoppingItem]

        var id: String { title }
    }

    static let basketTitle = "Im Korb"

    var items: [ShoppingItem]

    /// Open items grouped by category (in a fixed order), followed by everything already in the basket.
    var sections: [Section] {
        var result: [Section] = []
        for group in ShoppingGroup.allCases {
            let open = items.filter { $0.group == group && !$0.isInBasket }
            if !open.isEmpty {
                result.append(Section(title: group.rawValue, items: open))
            }
        }
        let basket = items.filter(\.isInBasket)
        if !basket.isEmpty {
            result.append(Section(title: Self.basketTitle, items: basket))
        }
        return result
    }

    var inBasketCount: Int {
        items.filter(\.isInBasket).count
    }

    mutating func toggle(_ id: String) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].isInBasket.toggle()
    }

    /// Adds an item to "Sonstiges". Blank names are rejected and return false.
    @discardableResult
    mutating func add(name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        items.append(ShoppingItem(id: UUID().uuidString, name: trimmed, group: .other))
        return true
    }
}
