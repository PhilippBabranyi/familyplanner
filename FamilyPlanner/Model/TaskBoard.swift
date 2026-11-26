enum TaskStatus: CaseIterable {
    case open
    case doing
    case done

    /// The status a task moves to when its button is tapped. Done tasks can be reopened.
    var next: TaskStatus {
        switch self {
        case .open: return .doing
        case .doing: return .done
        case .done: return .open
        }
    }

    var title: String {
        switch self {
        case .open: return "Offen"
        case .doing: return "Läuft"
        case .done: return "Fertig"
        }
    }

    var actionTitle: String {
        switch self {
        case .open: return "Starten"
        case .doing: return "Erledigt"
        case .done: return "Wieder öffnen"
        }
    }
}

struct TaskItem: Identifiable {
    let id: String
    var title: String
    /// Display name of the person the task is assigned to, nil if unassigned.
    var assignee: String?
    var assigneeId: String?
    /// Due date as `yyyy-MM-dd`, nil if there is none.
    var dueOn: String?
    /// Human-readable due date, e.g. "bis 28.11." or "ohne Datum".
    var due: String
    var status: TaskStatus
    /// Cash needed for the task in cents, e.g. money to bring to school.
    var cashCents: Int?
}

struct TaskBoard {
    var tasks: [TaskItem]

    func tasks(in status: TaskStatus) -> [TaskItem] {
        tasks.filter { $0.status == status }
    }

    func count(in status: TaskStatus) -> Int {
        tasks(in: status).count
    }

    /// Moves a task to its next status. Unknown ids are ignored.
    mutating func advance(_ id: String) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        tasks[index].status = tasks[index].status.next
    }
}
