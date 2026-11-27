import XCTest
@testable import FamilyPlanner

/// Two children with a pickup. Everything else comes from the demo data; the pickup writes are recorded.
private actor TwoChildSource: FamilyDataSource {
    private let demo = DemoDataSource()
    private(set) var driverWrites: [String] = []

    func loadTasks() async throws -> TaskBoard { try await demo.loadTasks() }
    func setTaskStatus(id: String, status: TaskStatus) async throws {}
    func saveTask(_ draft: TaskDraft) async throws {}
    func deleteTask(id: String) async throws {}
    func loadShoppingList() async throws -> ShoppingList { try await demo.loadShoppingList() }
    func addShoppingItem(name: String) async throws -> ShoppingItem { try await demo.addShoppingItem(name: name) }
    func setInBasket(id: String, inBasket: Bool) async throws {}
    func loadCalendar() async throws -> [CalendarData] {
        var kim = try await demo.loadCalendar().first ?? CalendarData()
        kim.child = PickupChild(id: "KIM", name: "Kim")
        var robin = kim
        robin.child = PickupChild(id: "ROBIN", name: "Robin")
        robin.pickups = [.monday: .at(14, 0), .thursday: .at(15, 30)]
        robin.pickupDrivers = [:]
        return [kim, robin]
    }
    func saveCalendarItem(_ draft: CalendarItemDraft) async throws {}
    func deleteCalendarItem(id: String) async throws {}
    func setPickupTimes(_ times: [Weekday: TimeOfDay], child: String?) async throws {}
    func setPickupDriver(day: String, memberId: String?, child: String?) async throws {
        driverWrites.append("\(child ?? "-")|\(day)|\(memberId ?? "-")")
    }
    func setPickupOverride(day: String, override: PickupOverride?, child: String?) async throws {}
    func setPickupReminder(minutes: Int, child: String?) async throws {}
    func addHoliday(name: String, startsOn: String, endsOn: String) async throws {}
    func deleteHoliday(id: String) async throws {}
    func loadSuggestions() async throws -> [InboxSuggestion] { [] }
    func decideSuggestion(id: String, decision: SuggestionDecision) async throws {}
    func registerDevice(token: String) async throws {}
    func loadMembers() async throws -> [Member] { try await demo.loadMembers() }
    func currentMemberName() async throws -> String? { "Alex" }
}

@MainActor
final class PickupChildrenTests: XCTestCase {
    private func model(on day: String, source: TwoChildSource = TwoChildSource()) async throws -> WeekViewModel {
        let date = try XCTUnwrap(WeekBuilder.date(fromISO: day, calendar: WeekBuilder.calendar()))
        let model = WeekViewModel(source: source, now: date)
        await model.load()
        return model
    }

    func testEveryChildHasAPickupOfTheirOwn() async throws {
        let model = try await model(on: "2026-11-26")
        XCTAssertEqual(model.children.map(\.name), ["Kim", "Robin"])
        XCTAssertEqual(model.childLabel(for: "ROBIN"), "Pickup Robin")
        XCTAssertEqual(model.weekPlan(for: "KIM").pickupTime(on: .thursday), .at(16, 20))
        XCTAssertEqual(model.weekPlan(for: "ROBIN").pickupTime(on: .thursday), .at(15, 30))
    }

    func testTodayShowsOnePickupPerChild() async throws {
        let model = try await model(on: "2026-11-26")
        XCTAssertEqual(model.todayPickups.map(\.label), ["Pickup Kim", "Pickup Robin"])
    }

    func testTheBellListsTheOpenPickupOfEachChild() async throws {
        let model = try await model(on: "2026-11-26")
        let noon = try XCTUnwrap(WeekBuilder.calendar().date(bySettingHour: 12, minute: 0, second: 0, of: model.today))
        let open = model.openPickups(now: noon)
        XCTAssertEqual(open.filter { $0.dayText == "2026-11-26" }.map(\.label), ["Pickup Kim", "Pickup Robin"])
        XCTAssertEqual(Set(open.map(\.id)).count, open.count, "the ids are different for each child")
    }

    func testAPickupDriverIsWrittenForTheRightChild() async throws {
        let source = TwoChildSource()
        let model = try await model(on: "2026-11-26", source: source)
        _ = await model.setPickupDriver(dayText: "2026-11-27", memberId: "Alex", child: "ROBIN")
        let writes = await source.driverWrites
        XCTAssertEqual(writes, ["ROBIN|2026-11-27|Alex"])
    }

    func testTheDayDotShowsTheMostUrgentMark() async throws {
        let model = try await model(on: "2026-11-23")
        // Monday: Kim's pickup has nobody yet in the demo, so the dot is red whatever Robin has.
        XCTAssertEqual(model.shownDot(on: .monday)?.mark, .open)
        XCTAssertNil(model.shownDot(on: .sunday))
    }
}
