/// Top-level destinations of the app.
enum Route: String, CaseIterable, Identifiable {
    case start
    case today
    case week
    case ask
    case tasks
    case shopping
    case more

    var id: String { rawValue }

    /// The tab that is highlighted while this destination is shown (Einkauf lives under "Mehr").
    var tab: Route { self == .shopping ? .more : self }

    /// Destinations shown in the floating tab bar. The start screen (the dandelion) is always the first one.
    static let tabs: [Route] = [.start, .today, .week, .ask, .tasks, .more]

    var title: String {
        switch self {
        case .start: return "Start"
        case .today: return "Heute"
        case .week: return "Woche"
        case .ask: return "Fragen"
        case .tasks: return "Aufgaben"
        case .shopping: return "Einkauf"
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
        case .shopping: return "cart"
        case .more: return "ellipsis"
        }
    }
}
