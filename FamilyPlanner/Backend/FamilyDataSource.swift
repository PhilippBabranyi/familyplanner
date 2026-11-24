import Foundation

/// Where tasks and the shopping list come from. Supabase in the app, in-memory data for UI tests.
protocol FamilyDataSource {
    func loadTasks() async throws -> TaskBoard
    func setTaskStatus(id: String, status: TaskStatus) async throws
    func loadShoppingList() async throws -> ShoppingList
    func addShoppingItem(name: String) async throws -> ShoppingItem
    func setInBasket(id: String, inBasket: Bool) async throws
    /// The plan of the week that starts on `weekStart` (a Monday).
    func loadWeek(starting weekStart: Date) async throws -> WeekPlan
    /// Display name of the signed-in person, if known.
    func currentMemberName() async throws -> String?
}

/// In-memory source with invented data. Used for UI tests and previews.
actor DemoDataSource: FamilyDataSource {
    private var board = DemoData.taskBoard
    private var list = DemoData.shoppingList

    func loadTasks() async throws -> TaskBoard { board }

    func setTaskStatus(id: String, status: TaskStatus) async throws {
        guard let index = board.tasks.firstIndex(where: { $0.id == id }) else { return }
        board.tasks[index].status = status
    }

    func loadShoppingList() async throws -> ShoppingList { list }

    func addShoppingItem(name: String) async throws -> ShoppingItem {
        let item = ShoppingItem(id: UUID().uuidString, name: name, group: .other)
        list.items.append(item)
        return item
    }

    func setInBasket(id: String, inBasket: Bool) async throws {
        guard let index = list.items.firstIndex(where: { $0.id == id }) else { return }
        list.items[index].isInBasket = inBasket
    }

    /// The demo week is fixed; it is shown for whichever week is requested.
    func loadWeek(starting weekStart: Date) async throws -> WeekPlan { DemoData.weekPlan }

    func currentMemberName() async throws -> String? { "Alex" }
}
