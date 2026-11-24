import XCTest
@testable import FamilyPlanner

private actor FailingSource: FamilyDataSource {
    func loadTasks() async throws -> TaskBoard { throw URLError(.notConnectedToInternet) }
    func setTaskStatus(id: String, status: TaskStatus) async throws { throw URLError(.notConnectedToInternet) }
    func loadShoppingList() async throws -> ShoppingList { throw URLError(.notConnectedToInternet) }
    func addShoppingItem(name: String) async throws -> ShoppingItem { throw URLError(.notConnectedToInternet) }
    func setInBasket(id: String, inBasket: Bool) async throws { throw URLError(.notConnectedToInternet) }
}

/// Loads fine but cannot save: used to check that optimistic changes are reverted.
private actor ReadOnlySource: FamilyDataSource {
    private let demo = DemoDataSource()

    func loadTasks() async throws -> TaskBoard { try await demo.loadTasks() }
    func setTaskStatus(id: String, status: TaskStatus) async throws { throw URLError(.notConnectedToInternet) }
    func loadShoppingList() async throws -> ShoppingList { try await demo.loadShoppingList() }
    func addShoppingItem(name: String) async throws -> ShoppingItem { throw URLError(.notConnectedToInternet) }
    func setInBasket(id: String, inBasket: Bool) async throws { throw URLError(.notConnectedToInternet) }
}

@MainActor
final class ViewModelTests: XCTestCase {
    func testTasksLoadFromSource() async {
        let model = TasksViewModel(source: DemoDataSource())
        await model.load()
        XCTAssertEqual(model.board.tasks.count, DemoData.taskBoard.tasks.count)
        XCTAssertNil(model.errorMessage)
    }

    func testTasksLoadFailureShowsMessage() async {
        let model = TasksViewModel(source: FailingSource())
        await model.load()
        XCTAssertEqual(model.errorMessage, "Aufgaben konnten nicht geladen werden.")
    }

    func testAdvanceIsSavedInSource() async throws {
        let source = DemoDataSource()
        let model = TasksViewModel(source: source)
        await model.load()
        await model.advance("gift")
        XCTAssertEqual(model.board.tasks.first { $0.id == "gift" }?.status, .doing)
        let stored = try await source.loadTasks()
        XCTAssertEqual(stored.tasks.first { $0.id == "gift" }?.status, .doing)
    }

    func testAdvanceIsRevertedWhenSavingFails() async {
        let model = TasksViewModel(source: ReadOnlySource())
        await model.load()
        await model.advance("gift")
        XCTAssertEqual(model.board.tasks.first { $0.id == "gift" }?.status, .open)
        XCTAssertEqual(model.errorMessage, "Die Änderung konnte nicht gespeichert werden.")
    }

    func testToggleIsRevertedWhenSavingFails() async {
        let model = ShoppingViewModel(source: ReadOnlySource())
        await model.load()
        await model.toggle("tomatoes")
        XCTAssertEqual(model.list.items.first { $0.id == "tomatoes" }?.isInBasket, false)
        XCTAssertNotNil(model.errorMessage)
    }

    func testAddAppendsItemAndIgnoresBlankNames() async {
        let model = ShoppingViewModel(source: DemoDataSource())
        await model.load()
        let before = model.list.items.count
        await model.add(name: "   ")
        XCTAssertEqual(model.list.items.count, before)
        await model.add(name: " Brot ")
        XCTAssertEqual(model.list.items.count, before + 1)
        XCTAssertEqual(model.list.items.last?.name, "Brot")
    }

    func testAddFailureKeepsListAndShowsMessage() async {
        let model = ShoppingViewModel(source: ReadOnlySource())
        await model.load()
        let before = model.list.items.count
        await model.add(name: "Brot")
        XCTAssertEqual(model.list.items.count, before)
        XCTAssertEqual(model.errorMessage, "Der Artikel konnte nicht hinzugefügt werden.")
    }
}

final class DatabaseMappingTests: XCTestCase {
    func testDueText() {
        XCTAssertEqual(DueText.make(from: "2026-11-28"), "bis 28.11.")
        XCTAssertEqual(DueText.make(from: "2027-01-05"), "bis 5.1.")
        XCTAssertEqual(DueText.make(from: nil), "ohne Datum")
        XCTAssertEqual(DueText.make(from: "kaputt"), "ohne Datum")
    }

    func testStatusRoundTrip() {
        for status in TaskStatus.allCases {
            XCTAssertEqual(TaskStatus(databaseValue: status.databaseValue), status)
        }
        XCTAssertNil(TaskStatus(databaseValue: "unknown"))
    }

    func testShoppingGroupMappingFallsBackToOther() {
        XCTAssertEqual(ShoppingGroup(databaseValue: "baking"), .baking)
        XCTAssertEqual(ShoppingGroup(databaseValue: "nonsense"), .other)
    }

    func testTaskRowDecodesAndResolvesAssigneeName() throws {
        let userId = UUID()
        let json = """
        {"id":"\(UUID().uuidString)","title":"Fenster putzen","assignee":"\(userId.uuidString)",
         "due_on":"2026-11-26","status":"doing"}
        """
        let row = try JSONDecoder().decode(TaskRow.self, from: Data(json.utf8))
        let item = row.makeItem(memberNames: [userId: "Sam"])
        XCTAssertEqual(item.assignee, "Sam")
        XCTAssertEqual(item.due, "bis 26.11.")
        XCTAssertEqual(item.status, .doing)
    }

    func testAssigneeColourIsStableAndUnassignedHasOwnColour() {
        XCTAssertEqual(AssigneePalette.index(for: "Alex"), AssigneePalette.index(for: "Alex"))
        XCTAssertLessThan(AssigneePalette.index(for: "Sam"), AssigneePalette.colors.count)
    }
}
