import Foundation

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
            errorMessage = "Aufgaben konnten nicht geladen werden."
        }
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
