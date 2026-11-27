import Foundation

/// The mail an AI-created task or event came from. Kept on the entry so it stays traceable later,
/// even after the mail itself is cleaned up.
struct MailSource: Equatable {
    /// The `inbox_items` row. Nil once that row was deleted (the cleanup removes old ones).
    var inboxItemId: String?
    var sender: String
    var subject: String
    var link: URL?
}

extension InboxSuggestion {
    var source: MailSource {
        MailSource(inboxItemId: id, sender: sender, subject: subject, link: link)
    }
}
