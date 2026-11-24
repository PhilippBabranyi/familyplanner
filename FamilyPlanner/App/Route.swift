/// Top-level destinations of the app.
enum Route: String, CaseIterable, Identifiable {
    case start
    case today
    case week
    case ask
    case tasks
    case more

    var id: String { rawValue }

    /// Destinations shown in the floating tab bar (the start screen is not one of them).
    static let tabs: [Route] = [.today, .week, .ask, .tasks, .more]

    var title: String {
        switch self {
        case .start: return "Start"
        case .today: return "Heute"
        case .week: return "Woche"
        case .ask: return "Fragen"
        case .tasks: return "Aufgaben"
        case .more: return "Mehr"
        }
    }

    var systemImage: String {
        switch self {
        case .start: return "leaf"
        case .today: return "clock"
        case .week: return "calendar"
        case .ask: return "magnifyingglass"
        case .tasks: return "checkmark.square"
        case .more: return "ellipsis"
        }
    }
}
