import Foundation

/// True for errors that only say "this request was cancelled", which must not show an error banner.
func isCancellation(_ error: Error) -> Bool {
    error is CancellationError || (error as? URLError)?.code == .cancelled
}

@MainActor
final class TasksViewModel: ObservableObject {
    @Published private(set) var board = TaskBoard(tasks: [])
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false

    private let source: FamilyDataSource

    init(source: FamilyDataSource) {
        self.source = source
    }

    func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            board = try await source.loadTasks()
            errorMessage = nil
        } catch {
            // A request that was cancelled (the view went away, a newer load started) is not an error.
            if isCancellation(error) { return }
            errorMessage = "Aufgaben konnten nicht geladen werden."
        }
    }

    func members() async -> [Member] {
        (try? await source.loadMembers()) ?? []
    }

    fileprivate func perform(
        _ failure: String,
        _ action: (FamilyDataSource) async throws -> Void
    ) async -> Bool {
        do {
            try await action(source)
        } catch {
            errorMessage = failure
            return false
        }
        await load()
        return true
    }

    /// Moves the task to its next status right away and undoes that if saving fails.
    func advance(_ id: String) async {
        guard let task = board.tasks.first(where: { $0.id == id }) else { return }
        let previous = board
        board.advance(id)
        do {
            try await source.setTaskStatus(id: id, status: task.status.next)
            errorMessage = nil
        } catch {
            board = previous
            errorMessage = "Die Änderung konnte nicht gespeichert werden."
        }
    }
}

extension TasksViewModel {
    /// Saves a new or edited task. Returns false (and shows a message) if saving failed.
    func save(_ draft: TaskDraft) async -> Bool {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        var clean = draft
        clean.title = title
        return await perform("Die Aufgabe konnte nicht gespeichert werden.") { try await $0.saveTask(clean) }
    }

    func delete(id: String) async -> Bool {
        await perform("Die Aufgabe konnte nicht gelöscht werden.") { try await $0.deleteTask(id: id) }
    }
}

@MainActor
final class ShoppingViewModel: ObservableObject {
    @Published private(set) var list = ShoppingList(items: [])
    @Published private(set) var errorMessage: String?

    private let source: FamilyDataSource

    init(source: FamilyDataSource) {
        self.source = source
    }

    func load() async {
        do {
            list = try await source.loadShoppingList()
            errorMessage = nil
        } catch {
            // A request that was cancelled (the view went away, a newer load started) is not an error.
            if isCancellation(error) { return }
            errorMessage = "Einkaufsliste konnte nicht geladen werden."
        }
    }

    func toggle(_ id: String) async {
        guard let item = list.items.first(where: { $0.id == id }) else { return }
        let previous = list
        list.toggle(id)
        do {
            try await source.setInBasket(id: id, inBasket: !item.isInBasket)
            errorMessage = nil
        } catch {
            list = previous
            errorMessage = "Die Änderung konnte nicht gespeichert werden."
        }
    }

    func add(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        do {
            let item = try await source.addShoppingItem(name: trimmed)
            list.items.append(item)
            errorMessage = nil
        } catch {
            errorMessage = "Der Artikel konnte nicht hinzugefügt werden."
        }
    }
}

@MainActor
final class WeekViewModel: ObservableObject {
    @Published private(set) var data = CalendarData()
    @Published private(set) var plan = WeekPlan(
        pickup: PickupSchedule(pickupDays: [], defaultTime: .at(15, 0), exceptions: [:]),
        itemsByDay: [:]
    )
    @Published private(set) var memberName: String?
    /// Family members with an account: they can be entered as the person who picks up.
    @Published private(set) var accounts: [Member] = []
    @Published private(set) var errorMessage: String?

    /// The week of today. Today's screen and the pickup logic always work on this week.
    let weekStart: Date
    /// The week the week screen currently shows; the person can leave the current week.
    @Published private(set) var shownWeekStart: Date
    let today: Date
    private let source: FamilyDataSource
    private let calendar = WeekBuilder.calendar()

    init(source: FamilyDataSource, now: Date = Date()) {
        self.source = source
        self.today = now
        let start = WeekBuilder.weekStart(containing: now, calendar: WeekBuilder.calendar())
        self.weekStart = start
        self.shownWeekStart = start
    }

    /// The plan of the week that the week screen shows.
    var shownPlan: WeekPlan {
        WeekBuilder.plan(data: data, weekStart: shownWeekStart, calendar: calendar)
    }

    var isShowingCurrentWeek: Bool { shownWeekStart == weekStart }

    /// Whole weeks between the current week and the shown one (negative: in the past).
    var shownWeekOffset: Int {
        let days = calendar.dateComponents([.day], from: weekStart, to: shownWeekStart).day ?? 0
        return Int((Double(days) / 7).rounded())
    }

    func showWeek(offsetBy weeks: Int) {
        if let next = calendar.date(byAdding: .day, value: 7 * weeks, to: shownWeekStart) {
            shownWeekStart = next
        }
    }

    func showWeek(containing date: Date) {
        shownWeekStart = WeekBuilder.weekStart(containing: date, calendar: calendar)
    }

    func showCurrentWeek() {
        shownWeekStart = weekStart
    }

    func shownDate(of day: Weekday) -> Date {
        WeekBuilder.date(of: day, weekStart: shownWeekStart, calendar: calendar)
    }

    func shownDayNumber(_ day: Weekday) -> Int {
        calendar.component(.day, from: shownDate(of: day))
    }

    var todayWeekday: Weekday {
        WeekBuilder.weekday(of: today, calendar: calendar)
    }

    func date(of day: Weekday) -> Date {
        WeekBuilder.date(of: day, weekStart: weekStart, calendar: calendar)
    }

    func dayNumber(_ day: Weekday) -> Int {
        calendar.component(.day, from: date(of: day))
    }

    func members() async -> [Member] {
        (try? await source.loadMembers()) ?? []
    }

    func storedItem(id: String) -> StoredCalendarItem? {
        data.items.first { $0.id == id }
    }

    func load() async {
        // The name is fetched first and on its own, so that the greeting does not depend on the calendar.
        if let name = try? await source.currentMemberName() { memberName = name }
        if let members = try? await source.loadMembers() { accounts = members.filter { $0.personId == nil } }
        do {
            data = try await source.loadCalendar()
            plan = WeekBuilder.plan(data: data, weekStart: weekStart, calendar: calendar)
            errorMessage = nil
        } catch {
            // A request that was cancelled (the view went away, a newer load started) is not an error.
            if isCancellation(error) { return }
            errorMessage = "Der Wochenplan konnte nicht geladen werden."
        }
    }

    func save(_ draft: CalendarItemDraft) async -> Bool {
        let title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }
        var clean = draft
        clean.title = title
        return await change("Der Termin konnte nicht gespeichert werden.") { try await $0.saveCalendarItem(clean) }
    }

    func deleteItem(id: String) async -> Bool {
        await change("Der Termin konnte nicht gelöscht werden.") { try await $0.deleteCalendarItem(id: id) }
    }

    func savePickups(_ times: [Weekday: TimeOfDay], remindMinutes: Int? = nil) async -> Bool {
        await change("Die Abholzeiten konnten nicht gespeichert werden.") {
            try await $0.setPickupTimes(times)
            if let remindMinutes { try await $0.setPickupReminder(minutes: remindMinutes) }
        }
    }

    /// Enters who picks up on a day of the shown week, or nobody (nil).
    func setPickupDriver(day: Weekday, memberId: String?) async -> Bool {
        await setPickupDriver(dayText: FormDates.iso(shownDate(of: day)), memberId: memberId)
    }

    /// Enters who picks up on any day (`yyyy-MM-dd`), or nobody (nil).
    func setPickupDriver(dayText: String, memberId: String?) async -> Bool {
        await change("Die Abholung konnte nicht gespeichert werden.") {
            try await $0.setPickupDriver(day: dayText, memberId: memberId)
        }
    }

    /// Pickups of today (if not yet over) and tomorrow that nobody has taken over. They show up in the bell.
    func openPickups(now: Date = Date()) -> [OpenPickup] {
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let current = TimeOfDay.at(parts.hour ?? 0, parts.minute ?? 0)
        var result: [OpenPickup] = []
        for offset in 0...1 {
            guard let date = calendar.date(byAdding: .day, value: offset, to: now) else { continue }
            let start = WeekBuilder.weekStart(containing: date, calendar: calendar)
            let weekPlan = WeekBuilder.plan(data: data, weekStart: start, calendar: calendar)
            let day = WeekBuilder.weekday(of: date, calendar: calendar)
            guard weekPlan.pickupMark(on: day) == .open, let time = weekPlan.pickupTime(on: day) else { continue }
            if offset == 0 && time < current { continue }
            let dayText = WeekBuilder.isoString(date, calendar: calendar)
            result.append(OpenPickup(dayText: dayText, time: time, isToday: offset == 0))
        }
        return result
    }

    /// Changes the pickup of one day of the shown week; nil goes back to the weekly time.
    func setPickupOverride(day: Weekday, override: PickupOverride?) async -> Bool {
        let dayText = FormDates.iso(shownDate(of: day))
        return await change("Die Abholzeit konnte nicht gespeichert werden.") {
            try await $0.setPickupOverride(day: dayText, override: override)
        }
    }

    /// Name of the person who picks up on a day of the shown week.
    func driverName(on day: Weekday) -> String? {
        accountName(shownPlan.driverByDay[day])
    }

    /// Today's pickup, nil if there is none.
    var todayPickup: TodayPickup? {
        guard let time = plan.pickupTime(on: todayWeekday), let mark = plan.pickupMark(on: todayWeekday) else {
            return nil
        }
        return TodayPickup(time: time, driver: accountName(plan.driverByDay[todayWeekday]), mark: mark)
    }

    /// The next item of today that has not started yet, nil if there is none.
    func nextItemToday(at now: Date = Date()) -> WeekItem? {
        let parts = calendar.dateComponents([.hour, .minute], from: now)
        let current = TimeOfDay.at(parts.hour ?? 0, parts.minute ?? 0)
        return plan.items(on: todayWeekday).first { $0.time >= current }
    }

    private func accountName(_ id: String?) -> String? {
        guard let id else { return nil }
        return accounts.first { $0.id == id }?.name ?? "jemand"
    }

    func addHoliday(name: String, startsOn: String, endsOn: String) async -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, startsOn <= endsOn else { return false }
        return await change("Die Ferien konnten nicht gespeichert werden.") {
            try await $0.addHoliday(name: trimmed, startsOn: startsOn, endsOn: endsOn)
        }
    }

    func deleteHoliday(id: String) async -> Bool {
        await change("Die Ferien konnten nicht gelöscht werden.") { try await $0.deleteHoliday(id: id) }
    }

    /// Runs a write, then reloads. Shows `failure` and returns false if the write fails.
    private func change(
        _ failure: String,
        _ action: (FamilyDataSource) async throws -> Void
    ) async -> Bool {
        do {
            try await action(source)
        } catch {
            errorMessage = failure
            return false
        }
        await load()
        return true
    }
}

/// The bell: open suggestions from the mails, and the decision on each of them.
@MainActor
final class InboxViewModel: ObservableObject {
    @Published private(set) var suggestions: [InboxSuggestion] = []
    @Published private(set) var errorMessage: String?

    private let source: FamilyDataSource

    init(source: FamilyDataSource) {
        self.source = source
    }

    /// Number shown on the bell.
    var count: Int { suggestions.count }

    func load() async {
        do {
            suggestions = try await source.loadSuggestions()
            errorMessage = nil
        } catch {
            // A request that was cancelled (the view went away, a newer load started) is not an error.
            if isCancellation(error) { return }
            errorMessage = "Vorschläge konnten nicht geladen werden."
        }
    }

    /// Removes the suggestion right away and brings it back if saving the decision fails.
    func decide(_ id: String, _ decision: SuggestionDecision) async {
        let previous = suggestions
        suggestions.removeAll { $0.id == id }
        do {
            try await source.decideSuggestion(id: id, decision: decision)
            errorMessage = nil
        } catch {
            suggestions = previous
            errorMessage = "Die Entscheidung konnte nicht gespeichert werden."
        }
    }

    /// Hands the push address of this phone to the backend. Failing is not shown: the app works without push.
    func registerDevice(token: String) async {
        try? await source.registerDevice(token: token)
    }
}
