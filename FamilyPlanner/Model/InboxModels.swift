import Foundation

/// A suggestion that the AI created from a mail: something for the calendar or a task.
struct InboxSuggestion: Identifiable, Equatable {
    enum Kind: Equatable {
        case event
        case task
    }

    let id: String
    let kind: Kind
    var title: String
    /// `yyyy-MM-dd`, the day of the event or the due date of the task.
    var date: String?
    var time: TimeOfDay?
    /// Money to bring or pay, in the smallest unit of `currency`.
    var amountCents: Int?
    /// ISO code such as EUR or GBP. Nil means the mail did not name one.
    var currency: String?
    var summary: String
    var sender: String
    var subject: String
    var link: URL?

    /// "5,00 GBP" or nil. The amount is shown in the currency of the mail.
    var amountText: String? {
        guard let amountCents else { return nil }
        let euros = Double(amountCents) / 100
        let number = String(format: "%.2f", euros).replacingOccurrences(of: ".", with: ",")
        return "\(number) \(currency ?? "€")"
    }

    /// The amount can be taken over into the app's cash field only if it is in euros (or has no currency).
    var amountCentsInEuro: Int? {
        guard let amountCents else { return nil }
        return (currency == nil || currency == "EUR") ? amountCents : nil
    }

    /// "Fr. 4.12." style hint for the card: date and time, whatever is known.
    var whenText: String? {
        guard let date else { return nil }
        let day = DueText.short(date)
        guard let time else { return day }
        return "\(day) um \(time)"
    }
}

/// The part of `inbox_items.suggestion` that the app reads. Unknown or unusable values are dropped.
struct SuggestionPayload: Decodable {
    let kind: String
    let title: String
    let date: String?
    let time: String?
    let amount: Double?
    let currency: String?
    let summary: String
}

extension InboxSuggestion {
    /// Returns nil for suggestions with nothing to do (kind "none") or unreadable kinds.
    init?(id: String, payload: SuggestionPayload, sender: String, subject: String, link: String?) {
        switch payload.kind {
        case "event": self.kind = .event
        case "task": self.kind = .task
        default: return nil
        }
        self.id = id
        self.title = payload.title
        self.date = payload.date
        self.time = payload.time.flatMap { Self.parseTime($0) }
        self.amountCents = payload.amount.map { Int(($0 * 100).rounded()) }
        self.currency = payload.currency
        self.summary = payload.summary
        self.sender = sender
        self.subject = subject
        self.link = link.flatMap { URL(string: $0) }
    }

    private static func parseTime(_ text: String) -> TimeOfDay? {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let hour = Int(parts[0]), let minute = Int(parts[1]) else { return nil }
        return TimeOfDay(hour: hour, minute: minute)
    }
}

enum SuggestionDecision {
    case accepted
    case dismissed

    /// Value stored in the `inbox_items.status` column.
    var databaseValue: String {
        switch self {
        case .accepted: return "accepted"
        case .dismissed: return "dismissed"
        }
    }
}
