import Foundation

/// Where the family's data comes from. Supabase in the app, in-memory data for UI tests.
protocol FamilyDataSource {
    // Tasks
    func loadTasks() async throws -> TaskBoard
    func setTaskStatus(id: String, status: TaskStatus) async throws
    func saveTask(_ draft: TaskDraft) async throws
    func deleteTask(id: String) async throws

    // Shopping
    func loadShoppingList() async throws -> ShoppingList
    func addShoppingItem(name: String) async throws -> ShoppingItem
    func setInBasket(id: String, inBasket: Bool) async throws

    // Week, today, pickups, holidays
    func loadCalendar() async throws -> CalendarData
    func saveCalendarItem(_ draft: CalendarItemDraft) async throws
    func deleteCalendarItem(id: String) async throws
    /// Replaces all pickup times: weekdays that are missing have no pickup.
    func setPickupTimes(_ times: [Weekday: TimeOfDay]) async throws
    func addHoliday(name: String, startsOn: String, endsOn: String) async throws
    func deleteHoliday(id: String) async throws

    // People
    func loadMembers() async throws -> [Member]
    /// Display name of the signed-in person, if known.
    func currentMemberName() async throws -> String?
}

/// In-memory source with invented data. Used for UI tests and previews.
actor DemoDataSource: FamilyDataSource {
    private var board = DemoData.taskBoard
    private var list = DemoData.shoppingList
    private var calendar = DemoData.calendarData

    func loadTasks() async throws -> TaskBoard { board }

    func setTaskStatus(id: String, status: TaskStatus) async throws {
        guard let index = board.tasks.firstIndex(where: { $0.id == id }) else { return }
        board.tasks[index].status = status
    }

    func saveTask(_ draft: TaskDraft) async throws {
        let name = DemoData.members.first { $0.id == draft.assigneeId }?.name
        let due = DueText.make(from: draft.dueOn)
        if let id = draft.id, let index = board.tasks.firstIndex(where: { $0.id == id }) {
            board.tasks[index].title = draft.title
            board.tasks[index].assignee = name
            board.tasks[index].assigneeId = draft.assigneeId
            board.tasks[index].dueOn = draft.dueOn
            board.tasks[index].due = due
        } else {
            board.tasks.append(TaskItem(
                id: UUID().uuidString, title: draft.title, assignee: name, assigneeId: draft.assigneeId,
                dueOn: draft.dueOn, due: due, status: .open
            ))
        }
    }

    func deleteTask(id: String) async throws {
        board.tasks.removeAll { $0.id == id }
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

    func loadCalendar() async throws -> CalendarData { calendar }

    func saveCalendarItem(_ draft: CalendarItemDraft) async throws {
        let name = DemoData.members.first { $0.id == draft.assigneeId }?.name
        let item = StoredCalendarItem(
            id: draft.id ?? UUID().uuidString, title: draft.title,
            note: draft.note.isEmpty ? nil : draft.note, startsOn: draft.startsOn, time: draft.time,
            weekdays: draft.weekdays, repeatUntil: draft.repeatUntil, skipHolidays: draft.skipHolidays,
            assigneeId: draft.assigneeId, assignee: name, cashCents: draft.cashCents
        )
        if let index = calendar.items.firstIndex(where: { $0.id == item.id }) {
            calendar.items[index] = item
        } else {
            calendar.items.append(item)
        }
    }

    func deleteCalendarItem(id: String) async throws {
        calendar.items.removeAll { $0.id == id }
    }

    func setPickupTimes(_ times: [Weekday: TimeOfDay]) async throws {
        calendar.pickups = times
    }

    func addHoliday(name: String, startsOn: String, endsOn: String) async throws {
        calendar.holidays.append(Holiday(id: UUID().uuidString, name: name, startsOn: startsOn, endsOn: endsOn))
    }

    func deleteHoliday(id: String) async throws {
        calendar.holidays.removeAll { $0.id == id }
    }

    func loadMembers() async throws -> [Member] { DemoData.members }

    func currentMemberName() async throws -> String? { "Alex" }
}
