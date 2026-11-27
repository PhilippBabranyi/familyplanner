import Foundation
import Supabase

/// The `source_*` columns of `tasks` and `calendar_items`.
struct SourceRow: Decodable {
    let id: UUID
    let inboxItem: UUID?
    let sender: String?
    let subject: String?
    let link: String?

    enum CodingKeys: String, CodingKey {
        case id
        case inboxItem = "source_inbox_item"
        case sender = "source_sender"
        case subject = "source_subject"
        case link = "source_link"
    }

    var source: MailSource? {
        guard sender != nil || subject != nil || inboxItem != nil else { return nil }
        return MailSource(
            inboxItemId: inboxItem?.uuidString,
            sender: sender ?? "",
            subject: subject ?? "",
            link: link.flatMap { URL(string: $0) }
        )
    }
}

/// Encodes the `source_*` columns. Only used when inserting: the source of an entry never changes.
struct SourceColumns: Encodable {
    let source: MailSource

    enum CodingKeys: String, CodingKey {
        case inboxItem = "source_inbox_item"
        case sender = "source_sender"
        case subject = "source_subject"
        case link = "source_link"
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(source.inboxItemId.flatMap { UUID(uuidString: $0) }, forKey: .inboxItem)
        try container.encode(source.sender, forKey: .sender)
        try container.encode(source.subject, forKey: .subject)
        try container.encode(source.link?.absoluteString, forKey: .link)
    }
}

extension SupabaseDataSource {
    /// The mail references are an optional extra: before the migration is applied, or if the read fails,
    /// entries simply show without a reference.
    func loadSources(table: String) async -> [String: MailSource] {
        let rows: [SourceRow] = (try? await client.from(table)
            .select("id,source_inbox_item,source_sender,source_subject,source_link")
            .not("source_sender", operator: .is, value: "null")
            .execute().value) ?? []
        var result: [String: MailSource] = [:]
        for row in rows {
            if let source = row.source { result[row.id.uuidString] = source }
        }
        return result
    }
}
