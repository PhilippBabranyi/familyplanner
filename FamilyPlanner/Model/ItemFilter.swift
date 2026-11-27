/// Which items the week shows: everything, only mine, only one other person's, or only what is for the family.
enum ItemFilter: Hashable {
    case all
    case mine
    case person(String)
    case family

    /// `viewer` is the display name of the signed-in person. An item without an assignee is for the family.
    func matches(_ item: WeekItem, viewer: String?) -> Bool {
        switch self {
        case .all: return true
        case .mine: return item.assignee != nil && item.assignee == viewer
        case let .person(name): return item.assignee == name
        case .family: return item.assignee == nil
        }
    }
}

extension WeekItem {
    /// True for items of another person: on the start screen they are shown paler.
    func isForSomeoneElse(than viewer: String?) -> Bool {
        guard let assignee else { return false }
        return assignee != viewer
    }
}
