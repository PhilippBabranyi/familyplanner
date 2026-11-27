extension WeekItem {
    /// True for items of another person: on the start screen they are shown paler.
    func isForSomeoneElse(than viewer: String?) -> Bool {
        guard let assignee else { return false }
        return assignee != viewer
    }
}
