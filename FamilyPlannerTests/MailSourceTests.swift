import XCTest
@testable import FamilyPlanner

final class MailSourceTests: XCTestCase {
    private let source = MailSource(
        inboxItemId: "8F1B2C3D-0000-4000-8000-000000000001", sender: "teacher@school.example",
        subject: "Science fair", link: URL(string: "https://mail.google.com/mail/#all/abc")
    )

    private func json(_ value: some Encodable) throws -> [String: Any] {
        let data = try JSONEncoder().encode(value)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testSuggestionDraftsCarryTheMailAsSource() {
        let suggestion = InboxSuggestion(
            id: "1", kind: .event, title: "Fair", date: "2026-12-04", time: nil, amountCents: nil,
            currency: nil, summary: "", sender: "teacher@school.example", subject: "Science fair", link: nil
        )
        XCTAssertEqual(SuggestionDrafts.task(from: suggestion).source?.subject, "Science fair")
        XCTAssertEqual(SuggestionDrafts.event(from: suggestion).source?.sender, "teacher@school.example")
        XCTAssertEqual(SuggestionDrafts.event(from: suggestion).source?.inboxItemId, "1")
    }

    func testSourceIsSentWhenInsertingATask() throws {
        let write = TaskWrite(
            familyId: UUID(), title: "Bring", assignee: nil, assigneePerson: nil, dueOn: nil, dueTime: nil,
            cashCents: nil, source: source
        )
        let body = try json(write)
        XCTAssertEqual(body["source_sender"] as? String, "teacher@school.example")
        XCTAssertEqual(body["source_subject"] as? String, "Science fair")
        XCTAssertEqual(body["source_link"] as? String, "https://mail.google.com/mail/#all/abc")
        XCTAssertEqual(body["source_inbox_item"] as? String, "8F1B2C3D-0000-4000-8000-000000000001")
    }

    func testSourceIsNotSentWhenUpdatingATask() throws {
        let write = TaskWrite(
            familyId: nil, title: "Bring", assignee: nil, assigneePerson: nil, dueOn: nil, dueTime: nil,
            cashCents: nil, source: source
        )
        XCTAssertNil(try json(write)["source_sender"])
    }

    func testManualEntriesSendNoSourceColumns() throws {
        let write = TaskWrite(
            familyId: UUID(), title: "Bring", assignee: nil, assigneePerson: nil, dueOn: nil, dueTime: nil,
            cashCents: nil
        )
        let body = try json(write)
        XCTAssertNil(body["source_sender"])
        XCTAssertNil(body["source_inbox_item"])
    }

    func testSourceIsSentOnlyWhenInsertingAnEvent() throws {
        var draft = CalendarItemDraft(
            id: nil, title: "Fair", note: "", startsOn: "2026-12-04", time: .at(9, 0), weekdays: [],
            repeatUntil: nil, skipHolidays: false, assigneeId: nil, cashCents: nil, source: source
        )
        XCTAssertEqual(try json(CalendarItemWrite(familyId: UUID(), draft: draft))["source_subject"] as? String,
                       "Science fair")
        draft.id = "x"
        XCTAssertNil(try json(CalendarItemWrite(familyId: nil, draft: draft))["source_subject"])
    }

    func testSourceRowWithoutMailDataGivesNoSource() throws {
        let data = Data(#"{"id":"8F1B2C3D-0000-4000-8000-000000000002"}"#.utf8)
        XCTAssertNil(try JSONDecoder().decode(SourceRow.self, from: data).source)
    }

    func testSourceRowKeepsSenderAndSubjectAfterTheMailIsGone() throws {
        let text = #"{"id":"8F1B2C3D-0000-4000-8000-000000000002","source_inbox_item":null,"#
            + #""source_sender":"a@b.example","source_subject":"Hi","source_link":null}"#
        let found = try XCTUnwrap(JSONDecoder().decode(SourceRow.self, from: Data(text.utf8)).source)
        XCTAssertNil(found.inboxItemId)
        XCTAssertEqual(found.subject, "Hi")
    }
}
