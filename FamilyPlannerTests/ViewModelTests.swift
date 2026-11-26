import XCTest
@testable import FamilyPlanner

private actor FailingSource: FamilyDataSource {
    private let error: Error
    private let memberName: String?

    init(error: Error = URLError(.notConnectedToInternet), memberName: String? = nil) {
        self.error = error
        self.memberName = memberName
    }

    func loadTasks() async throws -> TaskBoard { throw error }
    func setTaskStatus(id: String, status: TaskStatus) async throws { throw error }
    func saveTask(_ draft: TaskDraft) async throws { throw error }
    func deleteTask(id: String) async throws { throw error }
    func loadShoppingList() async throws -> ShoppingList { throw error }
    func addShoppingItem(name: String) async throws -> ShoppingItem { throw error }
    func setInBasket(id: String, inBasket: Bool) async throws { throw error }
    func loadCalendar() async throws -> CalendarData { throw error }
    func saveCalendarItem(_ draft: CalendarItemDraft) async throws { throw error }
    func deleteCalendarItem(id: String) async throws { throw error }
    func setPickupTimes(_ times: [Weekday: TimeOfDay]) async throws { throw error }
    func addHoliday(name: String, startsOn: String, endsOn: String) async throws { throw error }
    func deleteHoliday(id: String) async throws { throw error }
    func loadSuggestions() async throws -> [InboxSuggestion] { throw error }
    func decideSuggestion(id: String, decision: SuggestionDecision) async throws { throw error }
    func registerDevice(token: String) async throws { throw error }
    func loadMembers() async throws -> [Member] { throw error }
    func currentMemberName() async throws -> String? {
        if let memberName { return memberName }
        throw error
    }
}

/// Loads fine but cannot save: used to check that optimistic changes are reverted.
private actor ReadOnlySource: FamilyDataSource {
    private let demo = DemoDataSource()
    private let error = URLError(.notConnectedToInternet)
    func loadTasks() async throws -> TaskBoard { try await demo.loadTasks() }
    func setTaskStatus(id: String, status: TaskStatus) async throws { throw error }
    func saveTask(_ draft: TaskDraft) async throws { throw error }
    func deleteTask(id: String) async throws { throw error }
    func loadShoppingList() async throws -> ShoppingList { try await demo.loadShoppingList() }
    func addShoppingItem(name: String) async throws -> ShoppingItem { throw error }
    func setInBasket(id: String, inBasket: Bool) async throws { throw error }
    func loadCalendar() async throws -> CalendarData { try await demo.loadCalendar() }
    func saveCalendarItem(_ draft: CalendarItemDraft) async throws { throw error }
    func deleteCalendarItem(id: String) async throws { throw error }
    func setPickupTimes(_ times: [Weekday: TimeOfDay]) async throws { throw error }
    func addHoliday(name: String, startsOn: String, endsOn: String) async throws { throw error }
    func deleteHoliday(id: String) async throws { throw error }
    func loadSuggestions() async throws -> [InboxSuggestion] { try await demo.loadSuggestions() }
    func decideSuggestion(id: String, decision: SuggestionDecision) async throws { throw error }
    func registerDevice(token: String) async throws { throw error }
    func loadMembers() async throws -> [Member] { try await demo.loadMembers() }
    func currentMemberName() async throws -> String? { nil }
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

    func testCancelledLoadShowsNoError() async {
        for error in [CancellationError() as Error, URLError(.cancelled)] {
            let model = TasksViewModel(source: FailingSource(error: error))
            await model.load()
            XCTAssertNil(model.errorMessage)
            let week = WeekViewModel(source: FailingSource(error: error))
            await week.load()
            XCTAssertNil(week.errorMessage)
        }
    }

    func testNewTaskIsSavedWithTrimmedTitleAndAssignee() async {
        let model = TasksViewModel(source: DemoDataSource())
        await model.load()
        let before = model.board.tasks.count
        let draft = TaskDraft(id: nil, title: " Müll raus ", assigneeId: "Sam", dueOn: "2026-11-28")
        let saved = await model.save(draft)
        XCTAssertTrue(saved)
        XCTAssertEqual(model.board.tasks.count, before + 1)
        let task = model.board.tasks.last
        XCTAssertEqual(task?.title, "Müll raus")
        XCTAssertEqual(task?.assignee, "Sam")
        XCTAssertEqual(task?.due, "bis 28.11.")
    }

    func testEditingATaskKeepsItsStatus() async {
        let model = TasksViewModel(source: DemoDataSource())
        await model.load()
        let saved = await model.save(TaskDraft(id: "cake", title: "Torte backen", assigneeId: nil, dueOn: nil))
        XCTAssertTrue(saved)
        let task = model.board.tasks.first { $0.id == "cake" }
        XCTAssertEqual(task?.title, "Torte backen")
        XCTAssertEqual(task?.status, .doing)
        XCTAssertNil(task?.assignee)
    }

    func testDeletingATaskRemovesIt() async {
        let model = TasksViewModel(source: DemoDataSource())
        await model.load()
        let deleted = await model.delete(id: "gift")
        XCTAssertTrue(deleted)
        XCTAssertNil(model.board.tasks.first { $0.id == "gift" })
    }

    func testFailedTaskSaveShowsMessage() async {
        let model = TasksViewModel(source: ReadOnlySource())
        let saved = await model.save(TaskDraft(id: nil, title: "Test", assigneeId: nil, dueOn: nil))
        XCTAssertFalse(saved)
        XCTAssertEqual(model.errorMessage, "Die Aufgabe konnte nicht gespeichert werden.")
    }

    func testBlankTaskTitleIsNotSaved() async {
        let model = TasksViewModel(source: DemoDataSource())
        let saved = await model.save(TaskDraft(id: nil, title: "  ", assigneeId: nil, dueOn: nil))
        XCTAssertFalse(saved)
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
        let item = row.makeItem(names: PeopleNames(members: [userId: "Sam"]))
        XCTAssertEqual(item.assignee, "Sam")
        XCTAssertEqual(item.due, "bis 26.11.")
        XCTAssertEqual(item.status, .doing)
    }

    func testAssigneeColourIsStableAndUnassignedHasOwnColour() {
        XCTAssertEqual(AssigneePalette.index(for: "Alex"), AssigneePalette.index(for: "Alex"))
        XCTAssertLessThan(AssigneePalette.index(for: "Sam"), AssigneePalette.colors.count)
    }
}

@MainActor
final class WeekViewModelTests: XCTestCase {
    func testLoadsPlanAndMemberName() async {
        let model = WeekViewModel(source: DemoDataSource())
        await model.load()
        XCTAssertEqual(model.memberName, "Alex")
        XCTAssertFalse(model.plan.items(on: .friday).isEmpty)
        XCTAssertNil(model.errorMessage)
    }

    func testSavingAnItemReloadsThePlan() async {
        let today = WeekBuilder.date(fromISO: "2026-11-24", calendar: WeekBuilder.calendar()) ?? Date()
        let model = WeekViewModel(source: DemoDataSource(), now: today)
        await model.load()
        let before = model.plan.items(on: .sunday).count
        let draft = CalendarItemDraft(
            id: nil, title: " Radfahren ", note: "", startsOn: "2026-11-29", time: .at(10, 0),
            weekdays: [], repeatUntil: nil, skipHolidays: false, assigneeId: "Alex", cashCents: nil
        )
        let saved = await model.save(draft)
        XCTAssertTrue(saved)
        XCTAssertEqual(model.plan.items(on: .sunday).count, before + 1)
        XCTAssertEqual(model.plan.items(on: .sunday).last?.title, "Radfahren")
        XCTAssertEqual(model.plan.items(on: .sunday).last?.assignee, "Alex")
    }

    func testBlankItemTitleIsNotSaved() async {
        let model = WeekViewModel(source: DemoDataSource())
        let draft = CalendarItemDraft(
            id: nil, title: "  ", note: "", startsOn: "2026-11-29", time: .at(10, 0),
            weekdays: [], repeatUntil: nil, skipHolidays: false, assigneeId: nil, cashCents: nil
        )
        let saved = await model.save(draft)
        XCTAssertFalse(saved)
    }

    func testFailedSaveShowsMessageAndReturnsFalse() async {
        let model = WeekViewModel(source: ReadOnlySource())
        await model.load()
        let draft = CalendarItemDraft(
            id: nil, title: "Radfahren", note: "", startsOn: "2026-11-29", time: .at(10, 0),
            weekdays: [], repeatUntil: nil, skipHolidays: false, assigneeId: nil, cashCents: nil
        )
        let saved = await model.save(draft)
        XCTAssertFalse(saved)
        XCTAssertEqual(model.errorMessage, "Der Termin konnte nicht gespeichert werden.")
    }

    func testHolidayRemovesPickupAfterAdding() async {
        let today = WeekBuilder.date(fromISO: "2026-11-24", calendar: WeekBuilder.calendar()) ?? Date()
        let model = WeekViewModel(source: DemoDataSource(), now: today)
        await model.load()
        XCTAssertNotNil(model.plan.pickup.time(on: .wednesday))
        let added = await model.addHoliday(name: "Herbst", startsOn: "2026-11-25", endsOn: "2026-11-26")
        XCTAssertTrue(added)
        XCTAssertNil(model.plan.pickup.time(on: .wednesday))
        XCTAssertEqual(model.plan.holidays[.wednesday], "Herbst")
    }

    func testHolidayEndingBeforeItStartsIsRejected() async {
        let model = WeekViewModel(source: DemoDataSource())
        let added = await model.addHoliday(name: "Herbst", startsOn: "2026-11-26", endsOn: "2026-11-25")
        XCTAssertFalse(added)
    }

    func testLoadFailureShowsMessage() async {
        let model = WeekViewModel(source: FailingSource())
        await model.load()
        XCTAssertEqual(model.errorMessage, "Der Wochenplan konnte nicht geladen werden.")
    }

    func testGreetingNameDoesNotDependOnTheCalendar() async {
        let model = WeekViewModel(source: FailingSource(memberName: "Sam"))
        await model.load()
        XCTAssertEqual(model.memberName, "Sam")
        XCTAssertNotNil(model.errorMessage)
    }

    func testTheDandelionIsTheFirstMenuEntry() {
        XCTAssertEqual(Route.tabs.first, .start)
    }

    func testDayNumbersFollowTheWeekOfToday() {
        let today = WeekBuilder.date(fromISO: "2026-11-24", calendar: WeekBuilder.calendar()) ?? Date()
        let model = WeekViewModel(source: DemoDataSource(), now: today)
        XCTAssertEqual(model.todayWeekday, .tuesday)
        XCTAssertEqual(model.dayNumber(.monday), 23)
        XCTAssertEqual(model.dayNumber(.sunday), 29)
    }

    func testWeekNavigationLeavesTodayUntouched() async {
        let today = WeekBuilder.date(fromISO: "2026-11-24", calendar: WeekBuilder.calendar()) ?? Date()
        let model = WeekViewModel(source: DemoDataSource(), now: today)
        XCTAssertTrue(model.isShowingCurrentWeek)
        model.showWeek(offsetBy: 1)
        XCTAssertFalse(model.isShowingCurrentWeek)
        XCTAssertEqual(model.shownWeekOffset, 1)
        XCTAssertEqual(model.shownDayNumber(.monday), 30)
        model.showWeek(offsetBy: -3)
        XCTAssertEqual(model.shownWeekOffset, -2)
        XCTAssertEqual(model.shownDayNumber(.monday), 9)
        // The current week, which "Heute" shows, did not move.
        XCTAssertEqual(model.dayNumber(.monday), 23)
        model.showCurrentWeek()
        XCTAssertTrue(model.isShowingCurrentWeek)
    }

    func testJumpToADateShowsItsWeek() {
        let today = WeekBuilder.date(fromISO: "2026-11-24", calendar: WeekBuilder.calendar()) ?? Date()
        let model = WeekViewModel(source: DemoDataSource(), now: today)
        let target = WeekBuilder.date(fromISO: "2026-12-24", calendar: WeekBuilder.calendar()) ?? Date()
        model.showWeek(containing: target)
        XCTAssertEqual(model.shownDayNumber(.thursday), 24)
        XCTAssertEqual(model.shownWeekOffset, 4)
    }

    // MARK: Mail suggestions

    func testSuggestionsLoadAndDeciding() async {
        let model = InboxViewModel(source: DemoDataSource())
        await model.load()
        XCTAssertEqual(model.count, DemoData.suggestions.count)
        await model.decide("s1", .dismissed)
        XCTAssertEqual(model.count, DemoData.suggestions.count - 1)
        XCTAssertNil(model.errorMessage)
    }

    func testFailedDecisionBringsTheSuggestionBack() async {
        let model = InboxViewModel(source: ReadOnlySource())
        await model.load()
        let before = model.count
        await model.decide("s1", .accepted)
        XCTAssertEqual(model.count, before)
        XCTAssertEqual(model.errorMessage, "Die Entscheidung konnte nicht gespeichert werden.")
    }

    func testSuggestionLoadFailureShowsMessage() async {
        let model = InboxViewModel(source: FailingSource())
        await model.load()
        XCTAssertEqual(model.errorMessage, "Vorschläge konnten nicht geladen werden.")
        XCTAssertEqual(model.count, 0)
    }

    func testTaskWithCashIsSaved() async {
        let model = TasksViewModel(source: DemoDataSource())
        let saved = await model.save(TaskDraft(id: nil, title: "Kostüm", assigneeId: nil, dueOn: nil, cashCents: 500))
        XCTAssertTrue(saved)
        XCTAssertEqual(model.board.tasks.last?.cashCents, 500)
    }
}
